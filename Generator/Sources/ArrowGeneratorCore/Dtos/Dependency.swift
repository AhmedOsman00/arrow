import Foundation
import SwiftSyntax

struct Dependency: Hashable, CustomStringConvertible {
  /// Whether this dependency is declared as a variable or method
  let dependencyType: DependencyType

  /// Optional name for disambiguation (from `@Named("...")` attribute)
  let name: String?

  /// The return type of this dependency
  let type: String

  /// The declaration syntax block (property name or method signature)
  let block: String

  /// Parameters required to construct this dependency
  let parameters: [Parameter]

  /// The `#if` clauses the declaration is nested in
  var condition: CompilationCondition = .none

  /// Whether the provider is marked `@MainActor`
  var isMainActor = false

  /// Unique identifier for this dependency in the format "name:type"
  /// Uses "_" as the name if no `@Named` attribute is present
  var id: DependencyID {
    DependencyID(Self.id(name: name, type: type))
  }

  /// Mirrors the container's keys: types are compared by their canonical spelling, and an
  /// unnamed dependency is keyed by its type name, so `@Name("Foo") Foo` and `Foo` collide.
  static func id(name: String?, type: String) -> String {
    let type = TypeName.canonical(type)
    let name = name == type ? nil : name
    return "\(name ?? "_"):\(type)"
  }

  /// The dependencies this one resolves when created (parameters without default values),
  /// given the IDs of every provided dependency.
  ///
  /// An optional parameter whose optional type isn't provided resolves its wrapped type with
  /// `tryResolve`: it depends on that type only when it's provided, and is never missing.
  func dependencies(provided: Set<String>) -> [ParameterID] {
    parameters.filter { $0.value == nil }.compactMap { parameter in
      guard parameter.isResolvedOptionally(provided: provided) else { return parameter.id }
      return parameter.wrappedID.flatMap { provided.contains($0.rawValue) ? $0 : nil }
    }
  }

  var description: String {
    """
    \(dependencyType) \(block)(\(parameters.map(\.description).joined(separator: ", "))) -> (\(type), "\(name ?? type)")
    """
  }

  /// The kind of declaration used to provide this dependency
  enum DependencyType: CaseIterable {
    /// A computed property (e.g., `var apiClient: APIClient { ... }`)
    case variable
    /// A method (e.g., `func makeService() -> Service { ... }`)
    case method
  }

  struct Parameter: Hashable, CustomStringConvertible {
    /// The Swift type of this parameter
    let type: String

    /// The parameter name (for labeled parameters)
    let name: String?

    /// Default value if this is a constant parameter
    let value: String?

    /// Dependency name for named resolution (from `@Named("...")` on parameter)
    let dependencyId: String?

    /// Unique identifier for this parameter in the format "dependencyId:type"
    /// Uses "_" if no dependency ID is specified
    var id: ParameterID {
      ParameterID(Dependency.id(name: dependencyId, type: type))
    }

    /// The type an optional parameter wraps (`Cache?` -> `Cache`), or nil when it isn't optional.
    var wrappedType: String? {
      TypeName.optionalWrapped(type)
    }

    /// The ID of the wrapped type, resolved with `tryResolve`.
    var wrappedID: ParameterID? {
      wrappedType.map { ParameterID(Dependency.id(name: dependencyId, type: $0)) }
    }

    /// Whether the registry resolves this parameter with `tryResolve(Wrapped.self)`: it's optional
    /// and no provider returns the optional type itself.
    func isResolvedOptionally(provided: Set<String>) -> Bool {
      !provided.contains(id.rawValue) && wrappedType != nil
    }

    var description: String {
      """
      \(name ?? ""): \(value ?? "resolver.resolve(\(type).self, \"\(dependencyId ?? "")\")")
      """
    }
  }
}
