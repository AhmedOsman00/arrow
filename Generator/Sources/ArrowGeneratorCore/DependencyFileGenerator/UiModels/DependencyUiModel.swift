import Foundation

struct DependencyUiModel {
    let id: DependencyID
    let module: String
    let isFunc: Bool
    let type: String
    let name: String
    let block: String
    let scope: String
    let parameters: [Parameter]

    struct Parameter {
        let type: String
        let label: String?
        let id: String
        let isLast: Bool
    }
}
