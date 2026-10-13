import Foundation

/// Describes the generated `DependencyRegistry` type.
struct RegistryConfiguration: Equatable {
  /// Name of the generated type, for example `AnalyticsDependencies`.
  let name: String

  /// Whether the type and its `register(in:)` are `public`, so another module can register it.
  let isPublic: Bool

  /// Builds a registry name from a module or directory name.
  ///
  /// Non-alphanumeric characters split words, each word is capitalized, and `Dependencies` is appended:
  /// `Analytics` -> `AnalyticsDependencies`, `my-pkg` -> `MyPkgDependencies`.
  static func defaultName(for base: String) -> String {
    let words = base.split { !$0.isLetter && !$0.isNumber }
    var name = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    if name.isEmpty {
      name = "App"
    } else if let first = name.first, first.isNumber {
      name = "_" + name
    }
    return name + "Dependencies"
  }
}
