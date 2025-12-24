import Foundation
import SwiftSyntax

/// Represents a single dependency provided by a dependency module.
///
/// A dependency can be either a computed property or a method that returns an instance.
/// Dependencies can have parameters (which become sub-dependencies) and can be named
/// using the `@Named("...")` attribute for disambiguation.
///
/// Example:
/// ```swift
/// class NetworkModule: SingletonScope {
///     @Named("production")
///     var apiClient: APIClient { APIClient(baseURL: "https://api.example.com") }
///
///     var service: NetworkService {
///         NetworkService(client: resolver.resolve("production"))
///     }
/// }
/// ```
struct Dependency: Hashable, Equatable, CustomStringConvertible {
    /// Whether this dependency is declared as a variable or method
    let dependencyType: DependencyType

    /// Optional name for disambiguation (from `@Named("...")` attribute)
    let name: String?

    /// The return type of this dependency
    let type: String

    /// The declaration syntax block (property name or method signature)
    let block: String

    /// Parameters required to construct this dependency
    let parameters: [Parameter]

    /// Unique identifier for this dependency in the format "name:type"
    /// Uses "_" as the name if no `@Named` attribute is present
    var id: String {
        "\(name ?? "_"):\(type)"
    }

    /// List of dependency IDs that this dependency requires (parameters without default values)
    var dependencies: [String] {
        parameters.filter { $0.value == nil }.map(\.id)
    }

    var description: String {
        """
        \(dependencyType) \(block)(\(parameters.map(\.description).joined(separator: ", "))) -> (\(type), "\(name ?? type)")
        """
    }

    /// The kind of declaration used to provide this dependency
    enum DependencyType: CaseIterable {
        /// A computed property (e.g., `var apiClient: APIClient { ... }`)
        case variable
        /// A method (e.g., `func makeService() -> Service { ... }`)
        case method
    }

    /// Represents a parameter of a dependency declaration
    ///
    /// Parameters can be:
    /// - Sub-dependencies: No default value, resolved from the container
    /// - Constants: Have default values, passed through to generated code
    /// - Named dependencies: Have a `dependencyId` specifying which named instance to resolve
    struct Parameter: Hashable, Codable, CustomStringConvertible {
        /// The Swift type of this parameter
        let type: String

        /// The parameter name (for labeled parameters)
        let name: String?

        /// Default value if this is a constant parameter
        let value: String?

        /// Dependency name for named resolution (from `@Named("...")` on parameter)
        let dependencyId: String?

        /// Unique identifier for this parameter in the format "dependencyId:type"
        /// Uses "_" if no dependency ID is specified
        var id: String {
            "\(dependencyId ?? "_"):\(type)"
        }

        var description: String {
            """
            \(name ?? ""): \(type) = \(value ?? (dependencyId == nil ? "resolver.resolved()" : "resolver.resolved(\"\(dependencyId!)\")"))
            """
        }
    }
}
