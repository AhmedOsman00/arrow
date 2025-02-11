import Foundation

class FilePresenter {
    private let types: [Dependency]

    var imports: Set<String> {
//        var imports = types.flatMap(\.imports).asSet()
//        imports.insert("Swinject")
        return []
    }

    var moduleNames: Set<String> {
//        types.map(\.module).asSet()
        []
    }

    init(types: [Dependency]) {
        self.types = types
    }

    func getObjects() -> [Object] {
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

