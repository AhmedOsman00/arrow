import Foundation

struct Parameter: Hashable, Codable, CustomStringConvertible {
    let name: String?
    let value: String?

    var description: String {
        return """
            \(name ?? ""): \(value ?? "resolver.resolved")
            """
    }
}
