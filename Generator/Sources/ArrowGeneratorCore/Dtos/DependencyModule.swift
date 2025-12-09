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

    enum ModuleType: String, CaseIterable {
        case `class`
        case `struct`
        case `extension`
    }

    enum Scope: String, Codable, CaseIterable {
        // ⚠️ SYNC: Keep the raw value in sync with names of protocols in Arrow/Sources/Arrow/DependencyScope
        case singleton = "SingletonScope"
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
