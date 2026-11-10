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
  /// `#if` condition to wrap the registration in, if any.
  var condition: String?
  /// Whether the provider or its module is `@MainActor`, so the factory must run on the main thread.
  var isMainActor = false

  struct Parameter {
    let type: String
    let label: String?
    /// Name to resolve, only set for `@Named` parameters.
    let id: String?
    let isLast: Bool
    /// Resolved with `tryResolve`, so `type` is the optional's wrapped type.
    var isOptional = false
  }
}
