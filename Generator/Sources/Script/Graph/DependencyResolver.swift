import Foundation

final class DependencyResolver {
    private let data: Set<DependencyModule>
    private let graph: [String: [String]]

    init(data: Set<DependencyModule>) {
        self.data = data
        self.graph = Dictionary(data.flatMap(\.types).map { ($0.id, $0.dependencies) }) { $1 }
    }

    /// Resolves the dependency graph and returns the order of dependencies.
    /// Throws an error if the graph is invalid (e.g., missing dependencies, duplicates, or cycles).
    func resolveAndValidate() throws -> [String] {
        try validate()
        return try resolve()
    }
    
    /// Resolves the dependency graph and returns the order of dependencies.
    /// Does not perform validation. Use `validate()` to check for errors.
    func resolve() throws -> [String] {
        var visited = Set<String>()
        var visiting = Set<String>()
        var order = [String]()
        
        func visit(_ node: String) throws {
            guard !visiting.contains(node) else {
                throw DependencyError.circularDependency(node, graph[node] ?? [])
            }
            
            guard !visited.contains(node) else { return }
            
            visiting.insert(node)
            for neighbor in graph[node] ?? [] {
                try visit(neighbor)
            }
            visiting.remove(node)
            visited.insert(node)
            order.append(node)
        }
        
        for node in graph.keys {
            try visit(node)
        }
        
        return order
    }

    /// Validates the dependency graph for missing dependencies and duplicates.
    func validate() throws {
        try validateAllDependencyFound()
        try validateNoDuplicateDependencies()
    }
    
    enum DependencyError: Error {
        case missingDependencies(Set<String>)
        case duplicateDependencies([String])
        case circularDependency(String, [String])
        
        var errorDescription: String? {
            switch self {
            case let .missingDependencies(missing):
                "Missing dependencies: \(missing.joined(separator: ", "))"
            case let .duplicateDependencies(duplicates):
                "Duplicate dependencies found: \(duplicates.joined(separator: ", "))"
            case let .circularDependency(node, path):
                "Circular dependency detected at '\(node)' with one of it's dependencies: " + path.joined(separator: " -> ")
            }
        }
    }
}

private extension DependencyResolver {
    func validateAllDependencyFound() throws {
        let dependencies = Set(data.flatMap(\.types).flatMap(\.dependencies))
        let missingDependencies = dependencies.subtracting(graph.keys)
        
        guard missingDependencies.isEmpty else {
            throw DependencyError.missingDependencies(missingDependencies)
        }
    }
    
    func validateNoDuplicateDependencies() throws {
        var set = Set<String>()
        let types = data.flatMap(\.types).map(\.id)
        let duplicateDependencies = types.filter { !set.insert($0).inserted }

        guard duplicateDependencies.isEmpty else {
            throw DependencyError.duplicateDependencies(duplicateDependencies)
        }
    }
}
