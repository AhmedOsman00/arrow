import Foundation
import SwiftSyntax

struct Type: Hashable, Codable, CustomStringConvertible {
    let module: String
    let scope: Scope
    let imports: Set<String>
    let name: String
    let block: String
    let parameters: [Parameter]
    var dependancies: [String]

    var description: String {
        return "\(name)"
    }
}
