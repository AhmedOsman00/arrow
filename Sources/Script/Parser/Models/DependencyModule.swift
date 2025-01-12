import Foundation

struct DependencyModule: Hashable, Equatable, CustomStringConvertible {
    let type: ModuleType
    let imports: Set<String>
    let name: String
    let scope: Scope
    let types: Set<DependencyType>

    var description: String {
        return "\(name)"
    }

    enum ModuleType {
        case `class`
        case `struct`
        case `extension`
    }

    enum Scope: String, Codable {
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
