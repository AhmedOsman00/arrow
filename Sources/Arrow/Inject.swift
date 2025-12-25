/// Property wrapper for automatic dependency injection with non-optional resolution.
/// Caches the resolved value to avoid repeated lookups.
/// Fatal error if dependency cannot be resolved.
///
/// Usage:
/// ```swift
/// class MyViewController {
///     @Inject var service: MyService
///     @Inject(name: "custom") var customService: MyService
/// }
/// ```
@propertyWrapper
public struct Inject<T> {
    private let name: String?
    private let cache: Cache<T>

    public var wrappedValue: T {
        get {
            if let cached = cache.value {
                return cached
            }
            let resolved = Container.shared.resolve(T.self, name: name)
            cache.value = resolved
            return resolved
        }
    }

    public init(name: String? = nil) {
        self.name = name
        self.cache = Cache()
    }

    private final class Cache<Value> {
        var value: Value?
    }
}

public typealias Presenter = Inject
public typealias ViewModel = Inject
