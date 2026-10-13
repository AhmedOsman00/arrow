import Foundation

/// Thread-safe dependency injection container for managing application dependencies.
///
/// `Container` is a singleton service locator that manages dependency registration and resolution.
/// It supports three lifecycle scopes (singleton, lazy singleton and transient) and provides type-safe
/// dependency injection.
///
/// ## Thread Safety
/// - Registration, resolution, and removal are all protected by a lock
/// - Factories run outside the lock, so a factory may resolve or register other dependencies
///
/// ## Keys
/// Dependencies are keyed by their type *and* name. The name defaults to the type name, so
/// `resolve(Foo.self)` and `resolve(Foo.self, name: "Foo")` find the same registration, while
/// the same name used for two different types never collides.
///
/// ## Usage
/// ```swift
/// // Register a dependency
/// Container.shared.register(MyService.self, objectScope: .singleton) { _ in
///     MyServiceImpl()
/// }
///
/// // Resolve a dependency
/// let service: MyService = Container.shared.resolve(MyService.self)
/// ```
///
public final class Container: Registerable, @unchecked Sendable {
  /// The shared singleton instance of the container.
  public static let shared = Container()

  /// Internal storage for registered dependencies, keyed by type and name.
  private var dependencies = [Key: Registration]()

  /// Guards `dependencies`. Never held while running a factory.
  private let lock = NSLock()

  private init() {}

  /// Registers a dependency in the container with the specified scope.
  ///
  /// - Parameters:
  ///   - type: The type of the dependency to register
  ///   - name: Optional custom name for the dependency. If nil, uses the type name
  ///   - objectScope: The lifecycle scope (`.singleton` or `.transient`)
  ///   - factory: A closure that creates the dependency instance
  ///
  /// - Note: For `.singleton` scope, the factory is invoked immediately and the instance is cached.
  ///         For `.lazySingleton` scope, the factory is invoked once, on the first `resolve()` call.
  ///         For `.transient` scope, the factory is stored and invoked on each `resolve()` call.
  ///
  /// - Precondition: A dependency with the same type and name must not already be registered
  ///
  /// ## Example
  /// ```swift
  /// // Register singleton
  /// Container.shared.register(MyService.self, objectScope: .singleton) { _ in
  ///     MyServiceImpl()
  /// }
  ///
  /// // Register transient with custom name
  /// Container.shared.register(MyService.self, name: "Primary", objectScope: .transient) { _ in
  ///     MyServiceImpl(type: .primary)
  /// }
  /// ```
  public func register<Dependency>(
    _ type: Dependency.Type,
    name: String?,
    objectScope: DependencyScope,
    factory: @escaping (Registerable) -> Dependency
  ) {
    let key = Key(type, name: name)
    let alreadyRegistered = { "Dependency \(key.name) of type '\(type)' is already registered." }
    locked {
      guard dependencies[key] == nil else { fatalError(alreadyRegistered()) }
    }

    // Built outside the lock so the factory can resolve or register other dependencies.
    let entry: Registration.Entry
    switch objectScope {
    case .singleton:
      entry = .instance(factory(self))
    case .lazySingleton:
      entry = .lazy(LazyInstance { factory(self) })
    case .transient:
      entry = .factory { factory(self) }
    }

    locked {
      guard dependencies[key] == nil else { fatalError(alreadyRegistered()) }
      dependencies[key] = Registration(typeName: "\(type)", entry: entry)
    }
  }

  /// Resolves a dependency from the container.
  ///
  /// - Parameters:
  ///   - type: The type of the dependency to resolve
  ///   - name: Optional custom name for named dependencies. If nil, uses the type name
  ///
  /// - Returns: The resolved dependency instance
  ///
  /// - Note: For transient dependencies, creates a new instance on each call.
  ///         For singleton dependencies, returns the cached instance.
  ///
  /// - Precondition: The dependency must be registered before calling resolve
  /// - Important: Crashes with a fatal error if the dependency is not found
  ///
  /// ## Example
  /// ```swift
  /// let service: MyService = Container.shared.resolve(MyService.self)
  /// let namedService: MyService = Container.shared.resolve(MyService.self, name: "Primary")
  /// ```
  public func resolve<Dependency>(_ type: Dependency.Type, name: String? = nil) -> Dependency {
    if let dependency = lookup(type, name: name) {
      return dependency
    }

    // Find related dependencies (those whose type or name mentions the requested type or name)
    let typeName = "\(type)"
    let name = name ?? typeName
    let relatedDependencies = locked {
      dependencies
        .filter { key, registration in
          [typeName, name].contains {
            registration.typeName.localizedCaseInsensitiveContains($0)
              || key.name.localizedCaseInsensitiveContains($0)
          }
        }
        .map { key, registration in "\(key.name) (\(registration.typeName))" }
    }
    .sorted()

    if relatedDependencies.isEmpty {
      fatalError("Dependency not found for type '\(type)' with name '\(name)'. No similar dependencies registered.")
    } else {
      let relatedList = relatedDependencies.joined(separator: "\n  - ")
      fatalError(
        """
        Dependency not found for type '\(type)' with name '\(name)'.

        Similar registered dependencies:
          - \(relatedList)
        """)
    }
  }

  /// Attempts to resolve a dependency, returning nil if not found instead of crashing.
  ///
  /// Use this method for optional dependencies that may or may not be registered.
  /// Prefer using the `@Autowire` property wrapper for cleaner syntax.
  ///
  /// - Parameters:
  ///   - type: The type of the dependency to resolve
  ///   - name: Optional custom name for named dependencies. If nil, uses the type name
  ///
  /// - Returns: The resolved dependency instance, or nil if not registered
  ///
  /// ## Example
  /// ```swift
  /// if let service: MyService = Container.shared.tryResolve(MyService.self) {
  ///     // Service is available
  /// } else {
  ///     // Service not registered, use fallback
  /// }
  /// ```
  public func tryResolve<Dependency>(_ type: Dependency.Type, name: String? = nil) -> Dependency? {
    lookup(type, name: name)
  }

  /// Removes a registered dependency from the container.
  ///
  /// Useful for testing scenarios or dynamic module management.
  /// After unregistration, subsequent `resolve()` calls will fail.
  ///
  /// - Parameters:
  ///   - type: The type of the dependency to unregister
  ///   - name: Optional custom name for named dependencies. If nil, uses the type name
  ///
  /// ## Example
  /// ```swift
  /// // Unregister a dependency
  /// Container.shared.unregister(MyService.self)
  ///
  /// // Unregister a named dependency
  /// Container.shared.unregister(MyService.self, name: "Primary")
  /// ```
  public func unregister<Dependency>(_ type: Dependency.Type, name: String? = nil) {
    locked {
      _ = dependencies.removeValue(forKey: Key(type, name: name))
    }
  }

  /// Removes all registered dependencies from the container.
  ///
  /// Useful for test cleanup between test cases to ensure a clean slate.
  ///
  /// - Warning: After calling reset, all dependencies must be re-registered before resolution.
  ///
  /// ## Example
  /// ```swift
  /// override func tearDown() {
  ///     Container.shared.reset()
  ///     super.tearDown()
  /// }
  /// ```
  public func reset() {
    locked {
      dependencies.removeAll()
    }
  }
}

private extension Container {
  struct Key: Hashable {
    let type: ObjectIdentifier
    let name: String

    init<Dependency>(_ type: Dependency.Type, name: String?) {
      self.type = ObjectIdentifier(type)
      self.name = name ?? "\(type)"
    }
  }

  struct Registration {
    enum Entry {
      case instance(Any)
      case lazy(LazyInstance)
      case factory(() -> Any)
    }

    /// Kept for error messages, since `ObjectIdentifier` isn't readable.
    let typeName: String
    let entry: Entry
  }

  func lookup<Dependency>(_ type: Dependency.Type, name: String?) -> Dependency? {
    let registration = locked { dependencies[Key(type, name: name)] }

    // Factories run outside the container lock so they can resolve their own dependencies.
    switch registration?.entry {
    case .instance(let instance):
      return instance as? Dependency
    case .lazy(let lazyInstance):
      return lazyInstance.value() as? Dependency
    case .factory(let factory):
      return factory() as? Dependency
    case nil:
      return nil
    }
  }

  /// Creates its value on first access, exactly once, even under concurrent access.
  ///
  /// Uses its own lock rather than the container's, so the factory can resolve other dependencies.
  final class LazyInstance: @unchecked Sendable {
    private let lock = NSLock()
    private let factory: () -> Any
    private var instance: Any?

    init(_ factory: @escaping () -> Any) {
      self.factory = factory
    }

    func value() -> Any {
      lock.lock()
      defer { lock.unlock() }

      if let instance {
        return instance
      }
      let created = factory()
      instance = created
      return created
    }
  }

  func locked<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }
}
