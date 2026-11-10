/// Macro for marking provider methods with custom names for dependency registration.
///
/// Use this macro to provide multiple implementations of the same type
/// by giving them unique names. The code generator will use these names
/// to register and resolve different instances.
///
/// - Parameter value: The custom name for this dependency provider
///
/// Declared in the opt-in `ArrowMacros` product, so only targets that use it build swift-syntax.
///
/// ## Usage
/// ```swift
/// import Arrow
/// import ArrowMacros
///
/// final class MyModule: TransientScope {
///     @Name("Primary")
///     func providePrimaryService() -> MyService {
///         MyServiceImpl(type: .primary)
///     }
///
///     @Name("Secondary")
///     func provideSecondaryService() -> MyService {
///         MyServiceImpl(type: .secondary)
///     }
/// }
/// ```
///
/// Resolution with named dependencies:
/// ```swift
/// let primary: MyService = Container.shared.resolve(MyService.self, name: "Primary")
/// let secondary: MyService = Container.shared.resolve(MyService.self, name: "Secondary")
/// ```
///
/// - Note: This is a peer macro that doesn't generate code itself. The code generator
///         reads the macro annotation to determine the registration name.
@attached(peer)
public macro Name(_ value: String) = #externalMacro(module: "Macros", type: "NameMacro")
