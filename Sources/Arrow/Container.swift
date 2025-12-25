import Foundation

/// Thread-safe dependency injection container for managing application dependencies.
///
/// `Container` is a singleton service locator that manages dependency registration and resolution.
/// It supports two lifecycle scopes (singleton and transient) and provides type-safe dependency injection.
///
/// ## Thread Safety
/// - Registration is thread-safe and protected by NSLock
/// - Resolution is NOT thread-safe - all registration must complete before resolution begins
/// - This design assumes registration happens at app startup before concurrent access
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
/// - Important: All `register()` calls must complete at app initialization before any `resolve()` calls.
public final class Container: Registerable {
    /// The shared singleton instance of the container.
    /// Exposed as `Registerable` protocol for better abstraction.
    nonisolated(unsafe) public static let shared: Registerable = Container()

    /// Internal storage for registered dependencies, keyed by type name or custom name.
    private var dependencies = [String: Any]()

    /// Lock for thread-safe registration.
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
    ///         For `.transient` scope, the factory is stored and invoked on each `resolve()` call.
    ///
    /// - Precondition: A dependency with the same name must not already be registered
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
        lock.lock()
        defer { lock.unlock() }

        let name = name ?? "\(type)"
        guard dependencies[name] == nil else {
            fatalError("Dependency \(name) is already registered.")
        }

        switch objectScope {
        case .singleton:
            dependencies[name] = factory(Self.shared)
        case .transient:
            dependencies[name] = {
                factory(Self.shared)
            }
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
        let name = name ?? "\(type)"

        if let dependency = dependencies[name] as? Dependency {
            return dependency
        }

        if let dependency = dependencies[name] as? () -> Dependency {
            return dependency()
        }

        // Find related dependencies (those containing the type name or requested name)
        let typeName = "\(type)"
        let relatedDependencies = dependencies.keys
            .filter { key in
                key.localizedCaseInsensitiveContains(typeName) ||
                (name != typeName && key.localizedCaseInsensitiveContains(name)) ||
                key.contains(name) ||
                key.contains(typeName)
            }
            .sorted()

        if relatedDependencies.isEmpty {
            fatalError("Dependency not found for type '\(type)' with name '\(name)'. No similar dependencies registered.")
        } else {
            let relatedList = relatedDependencies.joined(separator: "\n  - ")
            fatalError("""
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
        let name = name ?? "\(type)"

        if let dependency = dependencies[name] as? Dependency {
            return dependency
        }

        if let dependency = dependencies[name] as? () -> Dependency {
            return dependency()
        }

        return nil
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
        lock.lock()
        defer { lock.unlock() }

        let name = name ?? "\(type)"
        dependencies.removeValue(forKey: name)
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
        lock.lock()
        defer { lock.unlock() }

        dependencies.removeAll()
    }
}
