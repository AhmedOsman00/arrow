import SwiftParser
import SwiftSyntax

/// Helpers for type names taken verbatim from source.
enum TypeName {
  /// Spelling used to compare types, so equivalent spellings resolve to the same dependency:
  /// `Array<String>` -> `[String]`, `Optional<Foo>` -> `Foo?`, `[String : Int]` -> `[String:Int]`.
  static func canonical(_ type: String) -> String {
    var parser = Parser(type)
    let syntax = SugarRewriter(viewMode: .sourceAccurate).rewrite(TypeSyntax.parse(from: &parser))
    return syntax.tokens(viewMode: .sourceAccurate)
      .map { spacedKeywords.contains($0.tokenKind) ? $0.text + " " : $0.text }
      .joined()
      .trimmingCharacters(in: .whitespaces)
  }

  private static let spacedKeywords: Set<TokenKind> = [
    .keyword(.any), .keyword(.some), .keyword(.each), .keyword(.inout), .keyword(.async), .keyword(.throws),
    .keyword(.borrowing), .keyword(.consuming), .keyword(.sending), .keyword(.repeat),
  ]

  /// The type an optional wraps: `Foo?`, `Foo!` and `Optional<Foo>` -> `Foo`, `(any Foo)?` -> `any Foo`.
  /// Returns nil when the type isn't optional.
  static func optionalWrapped(_ type: String) -> String? {
    var parser = Parser(type)
    let syntax = TypeSyntax.parse(from: &parser)
    guard let wrapped = wrappedType(of: syntax) else { return nil }
    // Drop the parentheses that `(any Foo)?` needs, so it matches a provider of `any Foo`.
    let tuple = wrapped.as(TupleTypeSyntax.self)
    if let element = tuple?.elements.first, tuple?.elements.count == 1, element.firstName == nil {
      return element.type.trimmedDescription
    }
    return wrapped.trimmedDescription
  }

  private static func wrappedType(of syntax: TypeSyntax) -> TypeSyntax? {
    if let optional = syntax.as(OptionalTypeSyntax.self) {
      return optional.wrappedType
    }
    if let optional = syntax.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
      return optional.wrappedType
    }
    guard let identifier = syntax.as(IdentifierTypeSyntax.self), identifier.name.text == "Optional",
      let arguments = identifier.genericArgumentClause?.arguments, arguments.count == 1,
      case .type(let argument) = arguments.first?.argument
    else { return nil }
    return argument
  }

  /// `Foo.self`, or `(any Foo).self` when the type isn't a plain name and needs grouping.
  static func metatypeExpression(_ type: String) -> String {
    let needsGrouping = type.contains { $0.isWhitespace || $0 == "&" } || type.contains("->")
    return needsGrouping ? "(\(type)).self" : "\(type).self"
  }
}

private final class SugarRewriter: SyntaxRewriter {
  override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
    let arguments = node.genericArgumentClause?.arguments.compactMap { argument -> TypeSyntax? in
      guard case .type(let type) = argument.argument else { return nil }
      return visit(type)
    }
    guard let arguments, arguments.count == node.genericArgumentClause?.arguments.count else {
      return super.visit(node)
    }
    switch (node.name.text, arguments.count) {
    case ("Array", 1):
      return TypeSyntax(ArrayTypeSyntax(element: arguments[0]))
    case ("Optional", 1):
      return TypeSyntax(OptionalTypeSyntax(wrappedType: arguments[0]))
    case ("Dictionary", 2):
      return TypeSyntax(DictionaryTypeSyntax(key: arguments[0], value: arguments[1]))
    default:
      return super.visit(node)
    }
  }
}
