import Foundation

protocol DependencyFilePresenting {
    var fileUiModel: FileUiModel { get }
}

class DependencyFilePresenter: DependencyFilePresenting {
    private let data: [DependencyModule]
    private let dependenciesOrder: [DependencyID]

    lazy var fileUiModel: FileUiModel = mapDependencyModulesToUiModule(data, dependenciesOrder)

    init(data: [DependencyModule], dependenciesOrder: [DependencyID]) {
        self.data = data
        self.dependenciesOrder = dependenciesOrder
    }

    private func mapDependencyModulesToUiModule(
        _ modules: [DependencyModule],
        _ dependenciesOrder: [DependencyID]
    ) -> FileUiModel {
        // Flatten the dependencies from all modules into a single array of DependencyUi
        let dependencies = modules.flatMap { module in
            module.types.map { dependency in
                let parameters = dependency.parameters.filter { $0.value == nil }
                return DependencyUiModel(
                    id: dependency.id,
                    module: module.name,
                    isFunc: dependency.dependencyType == .method,
                    type: dependency.type,
                    name: dependency.name ?? dependency.type,
                    block: dependency.block,
                    scope: module.scope.description,
                    parameters:
                        parameters
                        .map { parameter in
                            DependencyUiModel.Parameter(
                                type: parameter.type,
                                label: parameter.name == "_" ? nil : parameter.name,
                                id: parameter.dependencyId ?? parameter.type,
                                isLast: parameter == parameters.last)
                        }
                )
            }
        }

        var imports = modules.flatMap(\.imports).asSet()
        imports.insert("Arrow")  // Always import Arrow for Container type
        return FileUiModel(
            imports: imports,
            dependencies: sortDependencyUiModels(dependencies, dependenciesOrder)
        )
    }

    private func sortDependencyUiModels(
        _ dependencies: [DependencyUiModel],
        _ dependenciesOrder: [DependencyID]
    ) -> [DependencyUiModel] {
        let depsByType: [DependencyID: DependencyUiModel] = dependencies.reduce(into: [:]) { result, dependency in
            result[dependency.id] = dependency
        }
        return dependenciesOrder.compactMap { depsByType[$0] }
    }
}
