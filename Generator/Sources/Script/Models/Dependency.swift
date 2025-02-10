import Foundation
import SwiftSyntax

struct Dependency: Hashable, Equatable, CustomStringConvertible {
    let dependencyType: DependencyType
    let name: String?
    let type: String
    let block: String
    let parameters: [Parameter]
    var dependencies: [String]

    var id: String {
        "\(name ?? "_"):\(type)"
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
}
