import Foundation

enum Scope: String, Codable {
    case transient = "TransientScope"
    case graph = "GraphScope"
    case container = "ContainerScope"
    case weak = "WeakScope"
    
    var description: String {
        switch self {
        case .transient:
            return "transient"
        case .graph:
            return "graph"
        case .container:
            return "container"
        case .weak:
            return "weak"
        }
    }
}
