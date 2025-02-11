import Foundation
import SwiftSyntax

struct Dependency: Hashable, Equatable, CustomStringConvertible {
    let dependencyType: DependencyType
    let name: String?
    let type: String
    let block: String
    let parameters: [DependencyParameter]

    var id: String {
        "\(name ?? "_"):\(type)"
    }
    
    var dependencies: [String] {
        parameters.filter { $0.value == nil }.map(\.type)
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
