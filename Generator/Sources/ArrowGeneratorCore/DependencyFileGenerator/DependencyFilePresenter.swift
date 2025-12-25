import Foundation

/// Protocol defining the interface for presenting dependency file data
protocol DependencyFilePresenting {
  /// The UI model representing the entire generated file structure
  var fileUiModel: FileUiModel { get }
}

/// Transforms dependency modules into UI models for code generation.
///
/// This presenter acts as an intermediary between the parsed dependency data
/// and the code generator. It:
/// - Maps `DependencyModule` instances to `DependencyUiModel` instances
/// - Sorts dependencies according to the resolved topological order
/// - Collects all required imports
///
/// The UI models contain only the information needed for template-based code generation.
class DependencyFilePresenter: DependencyFilePresenting {
  /// The dependency modules to present
  private let data: [DependencyModule]

  /// Topological order of dependency IDs for correct registration sequence
  private let dependenciesOrder: [String]

  /// Lazily computed UI model for the generated file
  lazy var fileUiModel: FileUiModel = mapDependencyModulesToUiModule(data, dependenciesOrder)

  /// Initializes the presenter with dependency data
  ///
  /// - Parameters:
  ///   - data: Array of parsed dependency modules
  ///   - dependenciesOrder: Topologically sorted dependency IDs
  init(data: [DependencyModule], dependenciesOrder: [String]) {
    self.data = data
    self.dependenciesOrder = dependenciesOrder
  }

  /// Maps dependency modules to a file UI model
  ///
  /// - Parameters:
  ///   - modules: Array of dependency modules to transform
  ///   - dependenciesOrder: Topological order for sorting
  /// - Returns: Complete file UI model with imports and sorted dependencies
  private func mapDependencyModulesToUiModule(
    _ modules: [DependencyModule],
    _ dependenciesOrder: [String]
  ) -> FileUiModel {
    // Flatten the dependencies from all modules into a single array of DependencyUi
    let dependencies = modules.flatMap { module in
      module.types.map { dependency in
        DependencyUiModel(
          module: module.name,
          type: dependency.type,
          name: dependency.name ?? dependency.type,
          block: dependency.block,
          scope: module.scope.description,
          parameters: dependency.parameters.map { parameter in
            DependencyUiModel.Parameter(
              name: parameter.name == "_" ? nil : parameter.name,
              value: parameter.value,
              id: parameter.dependencyId,
              isLast: parameter == dependency.parameters.last)
          }
        )
      }
    }

    var imports = modules.flatMap(\.imports).asSet()
    imports.insert("Arrow")  // Always import Arrow for Container type
    return FileUiModel(
      imports: imports,
      dependencies: sortDependencyUiModels(dependencies, dependenciesOrder))
  }

  /// Sorts dependency UI models according to topological order
  ///
  /// - Parameters:
  ///   - dependencies: Unsorted array of dependency UI models
  ///   - dependenciesOrder: Topologically sorted dependency IDs
  /// - Returns: Dependencies sorted in registration order
  private func sortDependencyUiModels(
    _ dependencies: [DependencyUiModel],
    _ dependenciesOrder: [String]
  ) -> [DependencyUiModel] {
    let dependenciesByType: [String: DependencyUiModel] = dependencies.reduce(into: [:]) { result, dependency in
      result[dependency.id] = dependency
    }
    return dependenciesOrder.compactMap { dependenciesByType[$0] }
  }
}
