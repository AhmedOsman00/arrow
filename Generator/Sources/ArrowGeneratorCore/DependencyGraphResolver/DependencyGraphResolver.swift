import Foundation

/// Resolves and validates dependency graphs for Arrow dependency injection.
///
/// This resolver performs three key validations:
/// 1. **Missing dependencies**: Ensures all referenced dependencies are provided
/// 2. **Duplicate dependencies**: Ensures no two dependencies have the same type/name combination
/// 3. **Circular dependencies**: Detects cycles in the dependency graph
///
/// It then performs topological sorting to determine the correct registration order.
///
/// Example:
/// ```swift
/// let modules: [DependencyModule] = // ... parsed modules
/// let resolver = DependencyGraphResolver(data: modules)
/// let orderedDependencyIds = try resolver.resolveAndValidate()
/// // orderedDependencyIds can now be used to generate registration code
/// ```
final class DependencyGraphResolver {
  private let data: [DependencyModule]

  /// Adjacency list representing the dependency graph
  /// Key: dependency ID, Value: list of dependency IDs it depends on
  private let graph: [String: [String]]

  init(data: [DependencyModule]) {
    self.data = data
    let tuples = data.flatMap(\.types).map { ($0.id.rawValue, $0.dependencies.map(\.rawValue)) }
    self.graph = Dictionary(tuples) { $1 }
  }

  /// Validates the dependency graph and returns dependencies in topological order
  ///
  /// This method first validates the graph for errors (missing dependencies,
  /// duplicates) and then performs topological sorting. The returned order
  /// ensures that dependencies are registered before the types that depend on them.
  ///
  /// - Returns: Array of dependency IDs in registration order
  /// - Throws: `DependencyError` if validation fails or cycles are detected
  func resolveAndValidate() throws -> [DependencyID] {
    try validate()
    return try resolve()
  }

  /// Performs topological sort on the dependency graph using depth-first search
  ///
  /// Uses DFS with cycle detection to produce a topologically sorted list.
  /// Does not perform upfront validation - use `validate()` separately or use
  /// `resolveAndValidate()` for combined validation and resolution.
  ///
  /// - Returns: Array of dependency IDs in topological order
  /// - Throws: `DependencyError.circularDependency` with the full cycle if one is detected
  func resolve() throws -> [DependencyID] {
    var visited = Set<String>()
    var path = [String]()
    var order = [String]()

    func visit(_ node: String) throws {
      if let cycleStart = path.firstIndex(of: node) {
        throw DependencyError.circularDependency(Array(path[cycleStart...]) + [node])
      }

      guard !visited.contains(node) else { return }

      path.append(node)
      for neighbor in graph[node] ?? [] {
        try visit(neighbor)
      }
      path.removeLast()
      visited.insert(node)
      order.append(node)
    }

    // Sorted so the generated file is identical between runs.
    for node in graph.keys.sorted() {
      try visit(node)
    }

    return order.map { .init($0) }
  }

  /// Validates the dependency graph for structural errors
  ///
  /// Performs two validation checks:
  /// 1. All referenced dependencies must be provided by some module
  /// 2. No duplicate dependency definitions (same type/name combination)
  ///
  /// - Throws: `DependencyError.missingDependencies` or `DependencyError.duplicateDependencies`
  func validate() throws {
    try validateAllDependencyFound()
    try validateNoDuplicateDependencies()
  }

  enum DependencyError: LocalizedError {
    case missingDependencies(Set<String>)
    case duplicateDependencies([String])
    case circularDependency([String])

    var errorDescription: String? {
      switch self {
      case let .missingDependencies(missing):
        "Missing dependencies: \(missing.sorted().joined(separator: ", "))"
      case let .duplicateDependencies(duplicates):
        "Duplicate dependencies found: \(duplicates.sorted().joined(separator: ", "))"
      case let .circularDependency(cycle):
        "Circular dependency detected: \(cycle.joined(separator: " -> "))"
      }
    }
  }
}

private extension DependencyGraphResolver {
  func validateAllDependencyFound() throws {
    let dependencies = data.flatMap(\.types).flatMap(\.dependencies).map(\.rawValue).asSet()
    let missingDependencies = dependencies.subtracting(graph.keys)

    guard missingDependencies.isEmpty else {
      throw DependencyError.missingDependencies(missingDependencies)
    }
  }

  func validateNoDuplicateDependencies() throws {
    var set = Set<DependencyID>()
    let types = data.flatMap(\.types).map(\.id)
    let duplicateDependencies = types.filter { !set.insert($0).inserted }

    guard duplicateDependencies.isEmpty else {
      throw DependencyError.duplicateDependencies(duplicateDependencies.map(\.rawValue))
    }
  }
}
