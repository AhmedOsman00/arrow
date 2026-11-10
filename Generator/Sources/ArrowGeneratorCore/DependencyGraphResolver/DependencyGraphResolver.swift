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

  /// IDs of every provided dependency
  private let provided: Set<String>

  /// Adjacency list representing the dependency graph
  /// Key: dependency ID, Value: list of dependency IDs it depends on
  private let graph: [String: [String]]

  init(data: [DependencyModule]) {
    self.data = data
    let provided = data.flatMap(\.types).map(\.id.rawValue).asSet()
    let tuples = data.flatMap(\.types).map { ($0.id.rawValue, $0.dependencies(provided: provided).map(\.rawValue)) }
    self.provided = provided
    // Providers in different `#if` branches share an ID; the node depends on what either needs.
    self.graph = Dictionary(tuples) { $0 + $1 }
  }

  /// Warnings for singletons in `modules` that depend on a transient dependency.
  ///
  /// A singleton resolves its dependencies once, so it keeps a single instance of the transient
  /// dependency forever, which is rarely what the transient scope was chosen for.
  func captiveDependencyWarnings(in modules: [DependencyModule]) -> [String] {
    let transient = data.filter { $0.scope == .transient }.flatMap(\.types).map(\.id).asSet()
    return modules.filter { $0.scope != .transient }.flatMap { module in
      module.types.sorted { $0.id.rawValue < $1.id.rawValue }.flatMap { dependency in
        dependency.dependencies(provided: provided)
          .filter { transient.contains(DependencyID($0.rawValue)) }
          .map {
            "`\(module.name).\(dependency.block)` is a \(module.scope.description) but depends on transient "
              + "\(Self.describe($0.rawValue)), so it keeps one instance of it forever."
          }
      }
    }
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
  /// `_:Cache` -> `` `Cache` ``, `primary:Cache` -> `` `Cache` named "primary" ``.
  static func describe(_ id: String) -> String {
    let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return "`\(id)`" }
    return parts[0] == "_" ? "`\(parts[1])`" : "`\(parts[1])` named \"\(parts[0])\""
  }

  func validateAllDependencyFound() throws {
    let missingDependencies = Set(graph.values.joined()).subtracting(provided)

    guard missingDependencies.isEmpty else {
      throw DependencyError.missingDependencies(missingDependencies)
    }
  }

  /// Two providers may share an ID only when they sit in different branches of the same `#if`.
  func validateNoDuplicateDependencies() throws {
    var seen = [DependencyID: [Dependency]]()
    var duplicateDependencies = [DependencyID]()
    for dependency in data.flatMap(\.types) {
      let others = seen[dependency.id, default: []]
      if others.contains(where: { !$0.condition.isExclusive(with: dependency.condition) }) {
        duplicateDependencies.append(dependency.id)
      }
      seen[dependency.id] = others + [dependency]
    }

    guard duplicateDependencies.isEmpty else {
      throw DependencyError.duplicateDependencies(duplicateDependencies.map(\.rawValue))
    }
  }
}
