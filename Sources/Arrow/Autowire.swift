import Foundation

/// Property wrapper for automatic dependency injection with optional resolution.
/// Caches the resolved value to avoid repeated lookups.
/// Returns nil if dependency cannot be resolved instead of crashing. A missing dependency isn't
/// cached, so one registered after the first access is picked up on the next.
///
/// Usage:
/// ```swift
/// class MyViewController {
///     @Autowire var service: MyService?
///     @Autowire(name: "custom") var customService: MyService?
///     @Autowire(container: featureContainer) var isolatedService: MyService?
/// }
/// ```
@propertyWrapper
public struct Autowire<T> {
  private let name: String?
  private let container: Container
  private let cache: Cache<T>

  public var wrappedValue: T? {
    cache.value { container.tryResolve(T.self, name: name) }
  }

  /// - Parameters:
  ///   - name: Optional custom name for named dependencies. If nil, uses the type name
  ///   - container: The container to resolve from
  public init(name: String? = nil, container: Container = .shared) {
    self.name = name
    self.container = container
    self.cache = Cache()
  }

  private final class Cache<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var cached: Value?

    func value(orResolve resolve: () -> Value?) -> Value? {
      lock.lock()
      defer { lock.unlock() }

      if cached == nil {
        cached = resolve()
      }
      return cached
    }
  }
}
