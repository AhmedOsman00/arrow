import Foundation

class DependencyResolver {
    private let data: Set<DependencyModule>
    private let graph: [String: [String]]

    init(data: Set<DependencyModule>) {
        var graph = [String: [String]]()
        let dependencies = data.flatMap(\.types)
        for dependency in dependencies {
            graph[dependency.type] = dependency.dependencies
        }
        self.graph = graph
        self.data = data
    }

    func allDependencyFound() throws -> Bool {
        let dependencies = data.flatMap(\.types).flatMap(\.dependencies)
        let missingDependencies = dependencies.filter { graph[$0] == nil }
        if missingDependencies.isEmpty { return true }

        throw DependencyError.missingDependencies(missingDependencies)
    }

    func hasDuplicateDependencies() throws -> Bool {
        var set = Set<String>()
        let types = data.flatMap(\.types).map { "\($0.name ?? ""):\($0.type)" }
        let duplicateDependencies = types.filter { !set.insert($0).inserted }
        if duplicateDependencies.isEmpty { return false }

        throw DependencyError.duplicateDependencies(duplicateDependencies)
    }
    
    enum DependencyError: Error {
        case missingDependencies([String])
        case duplicateDependencies([String])
        case circularDependency(String, String)
    }
}
