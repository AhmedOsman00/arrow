/// Protocol defining the dependency injection container interface.
///
/// This protocol is implemented by `Container` and used by the code generator
/// to create registration extension methods. It provides the core operations
/// for dependency management: registration, resolution, and cleanup.
public protocol Registerable {
  /// Resolves a dependency, crashing if not found.
  func resolve<Dependency>(_ type: Dependency.Type, name: String?) -> Dependency

  /// Attempts to resolve a dependency, returning nil if not found.
  func tryResolve<Dependency>(_ type: Dependency.Type, name: String?) -> Dependency?

  /// Registers a dependency with the specified scope and factory.
  func register<Dependency>(
    _ type: Dependency.Type,
    name: String?,
    objectScope: DependencyScope,
    factory: @escaping (Registerable) -> Dependency)

  /// Removes a registered dependency.
  func unregister<Dependency>(_ type: Dependency.Type, name: String?)

  /// Removes all registered dependencies.
  func reset()
}

// Convenience overloads. They deliberately have fewer parameters than the requirements: an
// extension method with the same signature as a requirement becomes its default implementation,
// which here would call itself, so a conformer that missed a requirement would compile and then
// recurse forever instead of failing to build.
extension Registerable {
  public func resolve<Dependency>(_ type: Dependency.Type) -> Dependency {
    resolve(type, name: nil)
  }

  public func tryResolve<Dependency>(_ type: Dependency.Type) -> Dependency? {
    tryResolve(type, name: nil)
  }

  public func register<Dependency>(
    _ type: Dependency.Type,
    name: String? = nil,
    factory: @escaping (Registerable) -> Dependency
  ) {
    register(type, name: name, objectScope: .transient, factory: factory)
  }

  public func register<Dependency>(
    _ type: Dependency.Type,
    objectScope: DependencyScope,
    factory: @escaping (Registerable) -> Dependency
  ) {
    register(type, name: nil, objectScope: objectScope, factory: factory)
  }

  public func unregister<Dependency>(_ type: Dependency.Type) {
    unregister(type, name: nil)
  }

  public func resolved<Dependency>(name: String? = nil) -> Dependency {
    resolve(Dependency.self, name: name)
  }
}
