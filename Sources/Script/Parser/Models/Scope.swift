import Foundation

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
