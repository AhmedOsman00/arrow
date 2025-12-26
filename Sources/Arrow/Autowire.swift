/// Property wrapper for automatic dependency injection with optional resolution.
/// Caches the resolved value to avoid repeated lookups.
/// Returns nil if dependency cannot be resolved instead of crashing.
///
/// Usage:
/// ```swift
/// class MyViewController {
///     @Autowire var service: MyService?
///     @Autowire(name: "custom") var customService: MyService?
/// }
/// ```
@propertyWrapper
public struct Autowire<T> {
  private let name: String?
  private let cache: Cache<T>

  public var wrappedValue: T? {
    if cache.isInitialized {
      return cache.value
    }
    cache.value = Container.shared.tryResolve(T.self, name: name)
    cache.isInitialized = true
    return cache.value
  }

  public init(name: String? = nil) {
    self.name = name
    self.cache = Cache()
  }

  private final class Cache<Value> {
    var value: Value?
    var isInitialized = false
  }
}
