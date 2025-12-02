import Foundation
import SwiftSyntax

struct Dependency: Hashable, Equatable, CustomStringConvertible {
    let dependencyType: DependencyType
    let name: String?
    let type: String
    let block: String
    let parameters: [Parameter]

    var id: String {
        "\(name ?? "_"):\(type)"
    }
    
    var dependencies: [String] {
        parameters.filter { $0.value == nil }.map(\.id)
    }

    var description: String {
        """
        \(dependencyType) \(block)(\(parameters.map(\.description).joined(separator: ", "))) -> (\(type), "\(name ?? type)")
        """
    }

    enum DependencyType: CaseIterable {
        case variable
        case method
    }

    struct Parameter: Hashable, Codable, CustomStringConvertible {
        let type: String
        let name: String?
        let value: String?
        let dependencyId: String?

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
