import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import Macros

final class NameMacroTests: XCTestCase {
  private let macros: [String: Macro.Type] = ["Name": NameMacro.self]

  func testNameMacroLeavesDeclarationUnchanged() {
    assertMacroExpansion(
      """
      @Name("Primary")
      func providePrimary() -> Service {
        Service()
      }
      """,
      expandedSource: """
        func providePrimary() -> Service {
          Service()
        }
        """,
      macros: macros
    )
  }
}
