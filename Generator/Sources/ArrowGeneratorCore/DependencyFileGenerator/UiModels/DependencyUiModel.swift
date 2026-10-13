import Foundation

struct DependencyUiModel {
  let id: DependencyID
  let module: String
  let isFunc: Bool
  let type: String
  /// Registration name, only set for `@Name` providers; otherwise the runtime type name is used.
  let name: String?
  let block: String
  let scope: String
  let parameters: [Parameter]

  struct Parameter {
    let type: String
    let label: String?
    /// Name to resolve, only set for `@Named` parameters.
    let id: String?
    let isLast: Bool
  }
}
