import Constants
import Foundation

protocol DependencyFilePresenting {
  var fileUiModel: FileUiModel { get }
}

class DependencyFilePresenter: DependencyFilePresenting {
  private let data: [DependencyModule]
  private let dependenciesOrder: [DependencyID]
  private let registry: RegistryConfiguration

  lazy var fileUiModel: FileUiModel = mapDependencyModulesToUiModule(data, dependenciesOrder)

  /// - Parameters:
  ///   - data: Modules to emit. Dependencies in `dependenciesOrder` that no module here provides
  ///     (for example ones from another registry) are skipped.
  init(data: [DependencyModule], dependenciesOrder: [DependencyID], registry: RegistryConfiguration) {
    self.data = data
    self.dependenciesOrder = dependenciesOrder
    self.registry = registry
  }

  private func mapDependencyModulesToUiModule(
    _ modules: [DependencyModule],
    _ dependenciesOrder: [DependencyID]
  ) -> FileUiModel {
    // Every provided dependency is in the order, including ones from other registries.
    let provided = dependenciesOrder.map(\.rawValue).asSet()
    // Flatten the dependencies from all modules into a single array of DependencyUi
    let dependencies = modules.flatMap { module in
      module.types.map { dependency in
        let parameters = dependency.parameters.filter { $0.value == nil }
        return DependencyUiModel(
          id: dependency.id,
          module: module.name,
          isFunc: dependency.dependencyType == .method,
          type: dependency.type,
          name: dependency.name,
          block: dependency.block,
          scope: module.scope.description,
          parameters:
            parameters
            .enumerated()
            .map { index, parameter in
              let isOptional = parameter.isResolvedOptionally(provided: provided)
              return DependencyUiModel.Parameter(
                type: isOptional ? parameter.wrappedType ?? parameter.type : parameter.type,
                label: parameter.name == "_" ? nil : parameter.name,
                id: parameter.dependencyId,
                isLast: index == parameters.count - 1,
                isOptional: isOptional)
            },
          condition: dependency.condition.expression,
          isMainActor: module.isMainActor || dependency.isMainActor
        )
      }
    }

    var imports = modules.flatMap(\.imports).asSet()
    imports.insert("Arrow")  // Always import Arrow for Container type
    imports.remove(Constants.macrosModule)  // Only declares `@Name`, which the registry doesn't use
    if dependencies.contains(where: \.isMainActor) {
      imports.insert("Foundation")  // For the main-thread check's `Thread`
    }
    return FileUiModel(
      registry: registry,
      imports: imports.sorted(),
      dependencies: sortDependencyUiModels(dependencies, dependenciesOrder),
      conditionalImports: conditionalImports(modules, excluding: imports),
      moduleConditions: moduleConditions(modules),
      isMainActor: dependencies.contains(where: \.isMainActor)
    )
  }

  /// An import guarded differently in different files is emitted when any of its conditions holds.
  private func conditionalImports(_ modules: [DependencyModule], excluding imports: Set<String>) -> [String: String] {
    let conditions = modules.flatMap(\.conditionalImports).filter { !imports.contains($0.key) }
    return Dictionary(grouping: conditions, by: \.key).mapValues { entries in
      let distinct = entries.map(\.value).asSet().sorted()
      return distinct.count == 1 ? distinct[0] : distinct.map { "(\($0))" }.joined(separator: " || ")
    }
  }

  /// A module is only instantiated conditionally when every declaration of it shares the condition.
  private func moduleConditions(_ modules: [DependencyModule]) -> [String: String] {
    Dictionary(grouping: modules, by: \.name).compactMapValues { declarations in
      let conditions = declarations.map(\.condition).asSet()
      return conditions.count == 1 ? conditions.first?.expression : nil
    }
  }

  private func sortDependencyUiModels(
    _ dependencies: [DependencyUiModel],
    _ dependenciesOrder: [DependencyID]
  ) -> [DependencyUiModel] {
    // Several providers share an ID when they sit in different `#if` branches.
    let depsByType = Dictionary(grouping: dependencies, by: \.id)
      .mapValues { $0.sorted { ($0.condition ?? "") < ($1.condition ?? "") } }
    return dependenciesOrder.flatMap { depsByType[$0] ?? [] }
  }
}
