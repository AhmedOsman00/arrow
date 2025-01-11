import Foundation

class DependencyResolver {
    private let graph: Set<Type>
    private var weights: [Type: Int]
    private var types: [Type: String]
    private var dependants = [String: [Type]]()
    
    init(graph: Set<Type>) {
        self.graph = graph
        var weights = [Type: Int]()
        graph.forEach { weights[$0] = $0.dependancies.count }
        for type in graph {
            for dep in type.dependancies {
                if dependants[dep] == nil {
                    dependants[dep] = [type]
                } else {
                    dependants[dep]?.append(type)
                }
            }
        }
        var types = [Type: String]()
        graph.forEach { types[$0] = $0.name }
        self.types = types
        self.weights = weights
    }

    func resolve() throws -> [Type] {
        var zeros = [Type]()
        var sorted = [Type]()
        
        for (type, dependencies) in weights {
            if dependencies == 0 {
                zeros.append(type)
            }
        }

        for _ in 0..<graph.count {
            guard !zeros.isEmpty else {
                print("cycle found")
                throw NSError()
            }
            let x = zeros.removeFirst()
            sorted.append(x)
            let dependency = types[x]!
            
            guard let dependants = dependants[dependency] else {
                continue
            }
            
            for type in dependants {
                weights[type]! -= 1
                if weights[type] == 0 {
                    zeros.append(type)
                }
            }
        }
        return sorted
    }
}
