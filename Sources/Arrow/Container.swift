import Foundation

/// Thread-safe dependency injection container for managing application dependencies.
///
/// `Container` is a service locator that manages dependency registration and resolution. Apps
/// usually use `Container.shared`; tests can create their own container so they don't share state.
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
///
/// // An isolated container, for example one per test
/// let container = Container()
/// container.register(AppDependencies.self)
/// ```
///
public final class Container: Registerable, @unchecked Sendable {
  /// The shared singleton instance of the container.
  public static let shared = Container()

  /// Internal storage for registered dependencies, keyed by type and name.
  private var dependencies = [Key: Registration]()

  /// Guards `dependencies`. Never held while running a factory.
  private let lock = NSLock()

  /// Creates an empty container, independent of `shared`.
  public init() {}

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
    let description = key.description(typeName: "\(type)")
    let entry: Registration.Entry
    switch objectScope {
    case .singleton:
      entry = .instance(factory(self))
    case .lazySingleton:
      entry = .lazy(LazyInstance(description: description) { factory(self) })
    case .transient:
      entry = .factory { factory(self) }
    }

    locked {
      guard dependencies[key] == nil else { fatalError(alreadyRegistered()) }
      dependencies[key] = Registration(typeName: "\(type)", description: description, entry: entry)
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

    /// `'Service'`, or `'Service' named "primary"` when the name isn't the type name.
    func description(typeName: String) -> String {
      name == typeName ? "'\(typeName)'" : "'\(typeName)' named \"\(name)\""
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
    let description: String
    let entry: Entry
  }

  func lookup<Dependency>(_ type: Dependency.Type, name: String?) -> Dependency? {
    let key = Key(type, name: name)
    guard let registration = locked({ dependencies[key] }) else { return nil }

    // Factories run outside the container lock so they can resolve their own dependencies.
    switch registration.entry {
    case .instance(let instance):
      return instance as? Dependency
    case .lazy(let lazyInstance):
      return building(key, registration.description, lazyInstance.value) as? Dependency
    case .factory(let factory):
      return building(key, registration.description, factory) as? Dependency
    }
  }

  /// Runs `build` with `key` on this thread's resolution stack, crashing with the cycle's path if
  /// it's already there. Without this a transient cycle recurses until the stack overflows.
  func building(_ key: Key, _ description: String, _ build: () -> Any) -> Any {
    let stack = ResolutionStack.current
    let frame = ResolutionStack.Frame(container: ObjectIdentifier(self), key: key, description: description)
    if let start = stack.frames.firstIndex(where: { $0.container == frame.container && $0.key == key }) {
      let cycle = (stack.frames[start...] + [frame]).map(\.description).joined(separator: " -> ")
      fatalError("Circular dependency: \(cycle)")
    }

    stack.frames.append(frame)
    defer { stack.frames.removeLast() }
    return build()
  }

  /// The dependencies being built on the current thread, outermost first.
  final class ResolutionStack {
    struct Frame {
      let container: ObjectIdentifier
      let key: Key
      let description: String
    }

    private static let threadKey = "Arrow.Container.ResolutionStack"

    var frames = [Frame]()

    static var current: ResolutionStack {
      let storage = Thread.current.threadDictionary
      if let stack = storage[threadKey] as? ResolutionStack {
        return stack
      }
      let stack = ResolutionStack()
      storage[threadKey] = stack
      return stack
    }
  }

  /// Creates its value on first access, exactly once, even under concurrent access.
  ///
  /// Uses its own lock rather than the container's, so the factory can resolve other dependencies.
  /// The lock is recursive so a factory that resolves its own dependency, directly or through
  /// others, re-enters it and crashes with a message instead of deadlocking. A cycle split across
  /// threads is caught by `LazyCreations` before a thread starts waiting.
  final class LazyInstance: @unchecked Sendable {
    let description: String
    private let lock = NSRecursiveLock()
    private let factory: () -> Any
    private var instance: Any?
    private var isCreating = false

    init(description: String, _ factory: @escaping () -> Any) {
      self.description = description
      self.factory = factory
    }

    func value() -> Any {
      let thread = ObjectIdentifier(Thread.current)
      if !lock.try() {
        LazyCreations.shared.wait(on: self, from: thread)
        lock.lock()
        LazyCreations.shared.stopWaiting(from: thread)
      }
      defer { lock.unlock() }

      if let instance {
        return instance
      }
      // Other threads wait on the lock, so only the creating thread can get here mid-creation.
      guard !isCreating else {
        fatalError("Circular dependency: lazy singleton \(description) was resolved while it was being created.")
      }
      isCreating = true
      LazyCreations.shared.startCreating(self, on: thread)
      defer {
        isCreating = false
        LazyCreations.shared.finishCreating(self)
      }

      let created = factory()
      instance = created
      return created
    }
  }

  /// Which thread is creating each lazy singleton, and which one each thread is waiting for.
  ///
  /// Two threads that each create a lazy singleton the other needs would wait on each other's lock
  /// forever. Before waiting, a thread follows the chain of creators and what they wait for: if it
  /// leads back to itself, the singletons depend on each other, so it crashes with the path instead.
  final class LazyCreations: @unchecked Sendable {
    static let shared = LazyCreations()

    private let lock = NSLock()
    /// Lazy instance -> the thread creating it.
    private var creators = [ObjectIdentifier: ObjectIdentifier]()
    /// Thread -> the lazy instance it's waiting for.
    private var waits = [ObjectIdentifier: LazyInstance]()

    func startCreating(_ instance: LazyInstance, on thread: ObjectIdentifier) {
      lock.lock()
      defer { lock.unlock() }
      creators[ObjectIdentifier(instance)] = thread
    }

    func finishCreating(_ instance: LazyInstance) {
      lock.lock()
      defer { lock.unlock() }
      creators[ObjectIdentifier(instance)] = nil
    }

    func wait(on instance: LazyInstance, from thread: ObjectIdentifier) {
      lock.lock()
      defer { lock.unlock() }

      var chain = [instance]
      while let creator = creators[ObjectIdentifier(chain[chain.count - 1])] {
        if creator == thread {
          // The last instance in the chain is one this thread is creating, and it needs the first.
          let cycle = ([chain[chain.count - 1]] + chain).map(\.description).joined(separator: " -> ")
          fatalError("Circular dependency between lazy singletons resolved on different threads: \(cycle)")
        }
        guard let awaited = waits[creator] else { break }
        chain.append(awaited)
      }
      waits[thread] = instance
    }

    func stopWaiting(from thread: ObjectIdentifier) {
      lock.lock()
      defer { lock.unlock() }
      waits[thread] = nil
    }
  }

  func locked<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }
}
