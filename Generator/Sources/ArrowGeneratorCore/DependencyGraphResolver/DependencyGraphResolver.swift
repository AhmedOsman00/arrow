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
  /// Array of all dependency modules to resolve
  private let data: [DependencyModule]

  /// Adjacency list representing the dependency graph
  /// Key: dependency ID, Value: list of dependency IDs it depends on
  private let graph: [String: [String]]

  /// Initializes the resolver with dependency modules
  ///
  /// - Parameter data: Array of parsed dependency modules
  init(data: [DependencyModule]) {
    self.data = data
    self.graph = Dictionary(data.flatMap(\.types).map { ($0.id, $0.dependencies) }) { $1 }
  }

  /// Validates the dependency graph and returns dependencies in topological order
  ///
  /// This method first validates the graph for errors (missing dependencies,
  /// duplicates) and then performs topological sorting. The returned order
  /// ensures that dependencies are registered before the types that depend on them.
  ///
  /// - Returns: Array of dependency IDs in registration order
  /// - Throws: `DependencyError` if validation fails or cycles are detected
  func resolveAndValidate() throws -> [String] {
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
  /// - Throws: `DependencyError.circularDependency` if a cycle is detected
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

  /// Errors that can occur during dependency graph resolution
  enum DependencyError: LocalizedError {
    /// One or more dependencies are referenced but not provided
    case missingDependencies(Set<String>)

    /// Multiple dependencies with the same type/name combination exist
    case duplicateDependencies([String])

    /// A circular dependency was detected in the graph
    case circularDependency(String, [String])

    var errorDescription: String? {
      switch self {
      case let .missingDependencies(missing):
        "Missing dependencies: \(missing.joined(separator: ", "))"
      case let .duplicateDependencies(duplicates):
        "Duplicate dependencies found: \(duplicates.joined(separator: ", "))"
      case let .circularDependency(node, path):
        "Circular dependency detected at '\(node)' with one of it's dependencies: "
          + path.joined(separator: " -> ")
      }
    }
  }
}

private extension DependencyGraphResolver {
  /// Validates that all referenced dependencies are provided by modules
  ///
  /// Checks that every dependency ID referenced in parameters has a corresponding
  /// definition in one of the modules.
  ///
  /// - Throws: `DependencyError.missingDependencies` if any dependencies are missing
  func validateAllDependencyFound() throws {
    let dependencies = Set(data.flatMap(\.types).flatMap(\.dependencies))
    let missingDependencies = dependencies.subtracting(graph.keys)

    guard missingDependencies.isEmpty else {
      throw DependencyError.missingDependencies(missingDependencies)
    }
  }

  /// Validates that no duplicate dependency definitions exist
  ///
  /// Ensures that each dependency ID (type + name combination) appears only once
  /// across all modules. Duplicate definitions would create ambiguity.
  ///
  /// - Throws: `DependencyError.duplicateDependencies` if duplicates are found
  func validateNoDuplicateDependencies() throws {
    var set = Set<String>()
    let types = data.flatMap(\.types).map(\.id)
    let duplicateDependencies = types.filter { !set.insert($0).inserted }

    guard duplicateDependencies.isEmpty else {
      throw DependencyError.duplicateDependencies(duplicateDependencies)
    }
  }
}
