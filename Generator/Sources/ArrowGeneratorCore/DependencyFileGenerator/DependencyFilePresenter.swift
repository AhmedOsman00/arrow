import Foundation

protocol DependencyFilePresenting {
    var fileUiModel: FileUiModel { get }
}

class DependencyFilePresenter: DependencyFilePresenting {
    private let data: [DependencyModule]
    private let dependenciesOrder: [String]
    
    lazy var fileUiModel: FileUiModel = mapDependencyModulesToUiModule(data, dependenciesOrder)

    
    init(data: [DependencyModule], dependenciesOrder: [String]) {
        self.data = data
        self.dependenciesOrder = dependenciesOrder
    }
    
    private func mapDependencyModulesToUiModule(_ modules: [DependencyModule],
                                                _ dependenciesOrder: [String]) -> FileUiModel {
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
                        DependencyUiModel.Parameter(name: parameter.name == "_" ? nil : parameter.name,
                                                    value: parameter.value,
                                                    id: parameter.dependencyId,
                                                    isLast: parameter == dependency.parameters.last)
                    }
                )
            }
        }

        return FileUiModel(imports: modules.flatMap(\.imports).asSet(),
                           dependencies: sortDependencyUiModels(dependencies, dependenciesOrder))
    }
    
    private func sortDependencyUiModels(_ dependencies: [DependencyUiModel],
                                        _ dependenciesOrder: [String]) -> [DependencyUiModel] {
        let dependenciesByType: [String: DependencyUiModel] = dependencies.reduce(into: [:]) { result, dependency in
            result[dependency.id] = dependency
        }
        return dependenciesOrder.compactMap { dependenciesByType[$0] }
    }
}

