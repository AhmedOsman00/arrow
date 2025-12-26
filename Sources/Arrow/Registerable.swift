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

  /// Empty registration method for modules without dependencies.
  func register()
}

extension Registerable {
  public func resolve<Dependency>(_ type: Dependency.Type, name: String? = nil) -> Dependency {
    resolve(type, name: name)
  }

  public func tryResolve<Dependency>(_ type: Dependency.Type, name: String? = nil) -> Dependency? {
    tryResolve(type, name: name)
  }

  public func register<Dependency>(
    _ type: Dependency.Type,
    name: String? = nil,
    objectScope: DependencyScope = .transient,
    factory: @escaping (Registerable) -> Dependency
  ) {
    register(type, name: name, objectScope: objectScope, factory: factory)
  }

  public func unregister<Dependency>(_ type: Dependency.Type, name: String? = nil) {
    unregister(type, name: name)
  }

  func resolved<Dependency>() -> Dependency {
    return resolve(Dependency.self)
  }

  public func register() {}
}
