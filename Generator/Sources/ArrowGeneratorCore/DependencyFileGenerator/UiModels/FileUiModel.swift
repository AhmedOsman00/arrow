import Foundation

struct FileUiModel {
  let registry: RegistryConfiguration
  let imports: [String]
  let dependencies: [DependencyUiModel]
  /// Imports that must stay inside `#if`, keyed by module name.
  var conditionalImports: [String: String] = [:]
  /// `#if` condition for instantiating a module, keyed by module name.
  var moduleConditions: [String: String] = [:]
  /// Whether a module or provider is `@MainActor`, so the registry must be too.
  var isMainActor = false

  var modules: [String] {
    var seen = Set<String>()
    return dependencies.map(\.module).filter { seen.insert($0).inserted }
  }
}
