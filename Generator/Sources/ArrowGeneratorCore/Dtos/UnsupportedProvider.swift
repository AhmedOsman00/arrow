import Foundation
import SwiftSyntax

/// A module member that would be registered as a provider, but that the generated registry
/// can't call as written.
struct UnsupportedProvider: Hashable {
  /// The member's name, as written in the module
  let member: String

  /// Why the member can't be used as a provider
  let reason: String

  /// Where the member is declared, used to point the diagnostic at it
  let position: AbsolutePosition
}

enum ParserError: LocalizedError {
  /// Each entry is a diagnostic in the `file:line:column: error: message` form Xcode shows inline.
  case unsupportedProviders([String])

  var errorDescription: String? {
    switch self {
    case let .unsupportedProviders(diagnostics):
      "Unsupported providers:\n\(diagnostics.joined(separator: "\n"))"
    }
  }
}
