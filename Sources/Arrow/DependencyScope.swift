/// Base protocol for dependency modules, requiring a default initializer.
///
/// Used as a constraint for module scope protocols to ensure modules can be instantiated.
public protocol DependencyModule {
  init()
}

@available(*, deprecated, renamed: "DependencyModule")
public typealias Default = DependencyModule

/// Marker protocol for modules that provide transient-scoped dependencies.
///
/// Transient dependencies are created fresh on each resolution.
/// All provider methods in a module conforming to `TransientScope` will generate
/// transient registrations unless explicitly overridden.
///
/// ## Example
/// ```swift
/// final class MyModule: TransientScope {
///     init() {}
///
///     func provideService() -> MyService {
///         MyServiceImpl() // New instance created each time
///     }
/// }
/// ```
public protocol TransientScope: DependencyModule {}

/// Marker protocol for modules that provide singleton-scoped dependencies.
///
/// Singleton dependencies are created once during registration and reused.
/// All provider methods in a module conforming to `SingletonScope` will generate
/// singleton registrations unless explicitly overridden.
///
/// ## Example
/// ```swift
/// final class MyModule: SingletonScope {
///     init() {}
///
///     func provideService() -> MyService {
///         MyServiceImpl() // Created once, then cached
///     }
/// }
/// ```
public protocol SingletonScope: DependencyModule {}

/// Marker protocol for modules that provide lazily created singleton dependencies.
///
/// Lazy singleton dependencies are created once, on first resolution, and reused afterwards.
/// Use this for expensive dependencies that aren't needed at launch.
///
/// ## Example
/// ```swift
/// final class MyModule: LazySingletonScope {
///     init() {}
///
///     func provideDatabase() -> Database {
///         Database() // Created on first resolve, then cached
///     }
/// }
/// ```
public protocol LazySingletonScope: DependencyModule {}

/// Defines the lifecycle scope for dependency instances.
///
/// - `singleton`: Instance created once during registration and cached for reuse
/// - `lazySingleton`: Instance created once on first resolution and cached for reuse
/// - `transient`: New instance created on each resolution
public enum DependencyScope {
  /// Instance created once during registration and cached for reuse.
  case singleton

  /// Instance created once on first resolution and cached for reuse.
  case lazySingleton

  /// New instance created on each resolution.
  case transient
}
