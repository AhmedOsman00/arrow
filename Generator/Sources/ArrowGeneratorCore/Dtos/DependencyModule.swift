import Foundation

struct DependencyModule: Hashable, Equatable, CustomStringConvertible {
    let type: ModuleType
    let imports: Set<String>
    let name: String
    let scope: Scope
    let types: Set<Dependency>

    var description: String {
        """
    "\(name).\(type) in \(scope) imports \(imports) with members {
    \t\(types.map(\.description).joined(separator: "\n\t"))
    }
    """
    }

    /// The type of Swift declaration that defines the module
    enum ModuleType: String, CaseIterable {
        case `class`
        case `struct`
        case `extension`
    }

    /// The lifecycle scope of dependencies provided by this module
    enum Scope: String, Codable, CaseIterable {
        // ⚠️ SYNC: Keep the raw value in sync with names of protocols in Arrow/Sources/Arrow/DependencyScope

        /// Singleton scope - instances are created once and reused
        case singleton = "SingletonScope"

        /// Transient scope - new instances are created on each resolution
        case transient = "TransientScope"

        var description: String {
            switch self {
            case .singleton:
                return "singleton"
            case .transient:
                return "transient"
            }
        }
    }
}
