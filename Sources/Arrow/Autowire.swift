import Foundation

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
    cache.value { Container.shared.tryResolve(T.self, name: name) }
  }

  public init(name: String? = nil) {
    self.name = name
    self.cache = Cache()
  }

  private final class Cache<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var cached: Value?
    private var isInitialized = false

    func value(orResolve resolve: () -> Value?) -> Value? {
      lock.lock()
      defer { lock.unlock() }

      if !isInitialized {
        cached = resolve()
        isInitialized = true
      }
      return cached
    }
  }
}
