import SwiftSyntax

/// The `#if` clauses a declaration is nested in, outermost first. Empty when unconditional.
struct CompilationCondition: Hashable {
  struct Clause: Hashable {
    /// The `#if ... #endif` block this clause belongs to.
    let block: SyntaxIdentifier
    /// Position of the clause in its block (`#if` is 0, then each `#elseif` / `#else`).
    let index: Int
    /// Condition that selects this clause, including the negation of the clauses before it.
    let expression: String
  }

  static let none = CompilationCondition(clauses: [])

  let clauses: [Clause]

  /// The condition to emit in `#if`, or nil when unconditional.
  var expression: String? {
    clauses.isEmpty ? nil : clauses.map(\.expression).joined(separator: " && ")
  }

  /// Whether the two declarations can never be compiled together,
  /// because they sit in different clauses of the same `#if` block.
  func isExclusive(with other: CompilationCondition) -> Bool {
    clauses.contains { clause in
      other.clauses.contains { $0.block == clause.block && $0.index != clause.index }
    }
  }

  /// Collects the `#if` clauses enclosing `node`.
  init(of node: some SyntaxProtocol) {
    var clauses = [Clause]()
    var current = node.parent
    while let syntax = current {
      current = syntax.parent
      guard let clause = syntax.as(IfConfigClauseSyntax.self),
        let list = clause.parent?.as(IfConfigClauseListSyntax.self),
        let block = list.parent
      else { continue }

      let preceding = list.prefix { $0.id != clause.id }
      let negated = preceding.compactMap(\.condition).map { "!" + Self.grouped($0.trimmedDescription) }
      let own = clause.condition.map { [Self.grouped($0.trimmedDescription)] } ?? []
      clauses.insert(
        Clause(block: block.id, index: preceding.count, expression: (negated + own).joined(separator: " && ")),
        at: 0)
    }
    self.clauses = clauses
  }

  init(clauses: [Clause]) {
    self.clauses = clauses
  }

  /// `DEBUG` and `canImport(UIKit)` stay as they are, `A || B` becomes `(A || B)`.
  private static func grouped(_ expression: String) -> String {
    expression.contains(" ") ? "(\(expression))" : expression
  }
}
