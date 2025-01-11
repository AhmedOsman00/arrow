import Foundation
import SwiftSyntax

struct `Type`: Hashable, CustomStringConvertible {
    let module: String
    let scope: Scope
    let imports: Set<String>
    let name: String
    let type: String
    let block: String
    let parameters: [Parameter]
    var dependancies: [String]

    var description: String {
        return "\(name)"
    }
}

struct Module: Hashable, CustomStringConvertible {
    let name: String
    let scope: Scope
    let imports: Set<String>
    let types: Set<Type>

    var description: String {
        return "\(name)"
    }
}
