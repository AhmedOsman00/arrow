import Foundation
import SwiftSyntax

struct DependencyType: Hashable, Equatable, CustomStringConvertible {
    let name: String?
    let type: String
    let block: String
    let parameters: [Parameter]
    var dependencies: [String]

    var id: String {
        "\(name ?? "_"):\(type)"
    }

    var description: String {
        return name == nil ? type : "\(name!):\(type)"
    }
}
