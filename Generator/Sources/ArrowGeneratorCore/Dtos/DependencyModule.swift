import Foundation

/// Represents a Swift type (class, struct, or extension) that provides dependencies
/// through the Arrow DI framework.
///
/// A dependency module conforms to either `SingletonScope` or `TransientScope` and contains
/// one or more dependency declarations (properties or methods that provide instances).
///
/// Example:
/// ```swift
/// class NetworkModule: SingletonScope {
///     var apiClient: APIClient { APIClient() }
/// }
/// ```
struct DependencyModule: Hashable, Equatable, CustomStringConvertible {
  /// The type of Swift declaration (class, struct, or extension)
  let type: ModuleType

  /// Set of import statements required by this module
  let imports: Set<String>

  /// The name of the module type (e.g., "NetworkModule")
  let name: String

  /// The dependency scope (singleton or transient)
  let scope: Scope

  /// Set of dependencies provided by this module
  let types: Set<Dependency>

  var description: String {
    """
    "\(name).\(type) in \(scope) imports \(imports) with members {
    \t\(types.map(\.description).joined(separator: "\n\t"))
    }
    """
  }

  /// The type of Swift declaration that defines the module
  enum ModuleType: String, CaseIterable {
    /// A class declaration
    case `class`
    /// A struct declaration
    case `struct`
    /// An extension declaration
    case `extension`
  }

  /// The lifecycle scope of dependencies provided by this module
  enum Scope: String, Codable, CaseIterable {
    // ⚠️ SYNC: Keep the raw value in sync with names of protocols in Arrow/Sources/Arrow/DependencyScope

    /// Singleton scope - instances are created once and reused
    case singleton = "SingletonScope"

    /// Transient scope - new instances are created on each resolution
    case transient = "TransientScope"

    var description: String {
      switch self {
      case .singleton:
        return "singleton"
      case .transient:
        return "transient"
      }
    }
  }
}
