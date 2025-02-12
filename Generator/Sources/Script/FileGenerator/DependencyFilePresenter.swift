import Foundation

protocol DependencyFilePresenting {
    var imports: Set<String> { get }
    var moduleNames: Set<String> { get }
    var objects: [Object] { get }
}

class DependencyFilePresenter: DependencyFilePresenting {
    private let data: [DependencyModule]
    private let dependenciesOrder: [String]

    var imports: Set<String> {
//        var imports = types.flatMap(\.imports).asSet()
//        imports.insert("Swinject")
        return []
    }

    var moduleNames: Set<String> {
//        types.map(\.module).asSet()
        []
    }

    init(data: [DependencyModule], dependenciesOrder: [String]) {
        self.data = data
        self.dependenciesOrder = dependenciesOrder
    }

    var objects: [Object] {
//        types.map { type in
//            Object(module: type.module,
//                   name: type.name,
//                   block: type.block,
//                   scope: type.scope.description,
//                   args:  getArgs(type.parameters))
//        }
        []
    }

    private func getArgs(_ parameters: [DependencyParameter]) -> [Arg] {
        parameters.map {
            Arg(name: $0.name == "_" ? nil : $0.name,
                value: $0.value,
                comma: $0 == parameters.last)
        }
    }
}

