import Foundation

struct DependencyUiModel {
    let module: String
    let type: String
    let name: String
    let block: String
    let scope: String
    let parameters: [Parameter]

    var id: String {
        return "\(name):\(type)"
    }

    struct Parameter {
        let name: String?
        let value: String?
        let id: String?
        let isLast: Bool
    }
}
