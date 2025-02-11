import Foundation

struct DependencyParameter: Hashable, Codable, CustomStringConvertible {
    let type: String
    let name: String?
    let value: String?

    var description: String {
        """
        \(name ?? ""): \(type) = \(value ?? "resolver.resolved()")
        """
    }
}
