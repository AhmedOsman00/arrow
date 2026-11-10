import Foundation

/// Property wrapper for automatic dependency injection with non-optional resolution.
/// Caches the resolved value to avoid repeated lookups.
/// Fatal error if dependency cannot be resolved.
///
/// Usage:
/// ```swift
/// class MyViewController {
///     @Inject var service: MyService
///     @Inject(name: "custom") var customService: MyService
///     @Inject(container: featureContainer) var isolatedService: MyService
/// }
/// ```
@propertyWrapper
public struct Inject<T> {
  private let name: String?
  private let container: Container
  private let cache: Cache<T>

  public var wrappedValue: T {
    cache.value { container.resolve(T.self, name: name) }
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

    func value(orResolve resolve: () -> Value) -> Value {
      lock.lock()
      defer { lock.unlock() }

      if let cached {
        return cached
      }
      let resolved = resolve()
      cached = resolved
      return resolved
    }
  }
}

public typealias Presenter = Inject
public typealias ViewModel = Inject
