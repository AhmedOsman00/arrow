/// Property wrapper for marking named dependencies in method parameters.
/// This is a passthrough wrapper that does nothing but provides semantic markup.
///
/// Note: Use `@Name` macro for declarations and `@Named` property wrapper for parameters.
///
/// Usage:
/// ```swift
/// func configure(@Named("userId") id: Int, @Named("userName") name: String) {
///     // id and name are used directly as Int and String
/// }
///
/// // Works with optionals
/// func setup(@Named("config") config: Config?) {
///     // config is used as optional Config
/// }
///
/// // Works with any type
/// func process(@Named("data") items: [String]) {
///     // items is used as [String]
/// }
/// ```
@propertyWrapper
public struct Named<T> {
    public let wrappedValue: T
    private let name: String

    /// Initialize the Named property wrapper with a value and name.
    /// - Parameters:
    ///   - wrappedValue: The actual value being wrapped
    ///   - name: The name identifier for the dependency
    public init(wrappedValue: T, _ name: String) {
        self.wrappedValue = wrappedValue
        self.name = name
    }
}
