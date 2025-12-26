/// Base protocol requiring a default initializer.
///
/// Used as a constraint for module scope protocols to ensure modules can be instantiated.
public protocol Default {
  init()
}

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
public protocol TransientScope: Default {}

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
public protocol SingletonScope: Default {}

/// Defines the lifecycle scope for dependency instances.
///
/// - `singleton`: Instance created once during registration and cached for reuse
/// - `transient`: New instance created on each resolution
public enum DependencyScope {
  /// Instance created once during registration and cached for reuse.
  case singleton

  /// New instance created on each resolution.
  case transient
}
