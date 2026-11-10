import Constants
import Foundation
import SwiftSyntax

/// Extracts the provider declarations from a module's member block.
///
/// Only direct members are considered, so nested types and local functions are never
/// treated as providers. Members that can't be called on a module instance
/// (`private`, `fileprivate`, `static`, `class`) are skipped. Members the generated registry
/// can't call as written (`async`, `throws`, generic, or stored without an initializer) are
/// collected in `unsupportedProviders` instead.
struct DependenciesParser {
  private(set) var unsupportedProviders = [UnsupportedProvider]()

  mutating func parse(_ memberBlock: MemberBlockSyntax) -> Set<Dependency> {
    parse(memberBlock.members)
  }
}

private extension DependenciesParser {
  static let skippedModifiers: Set<Keyword> = [.private, .fileprivate, .static, .class]

  mutating func parse(_ members: MemberBlockItemListSyntax) -> Set<Dependency> {
    var dependencies = Set<Dependency>()
    for member in members {
      if let function = member.decl.as(FunctionDeclSyntax.self) {
        if let dependency = dependency(from: function) {
          dependencies.insert(dependency)
        }
      } else if let variable = member.decl.as(VariableDeclSyntax.self) {
        if let dependency = dependency(from: variable) {
          dependencies.insert(dependency)
        }
      } else if let ifConfig = member.decl.as(IfConfigDeclSyntax.self) {
        for clause in ifConfig.clauses {
          if case .decls(let nestedMembers) = clause.elements {
            dependencies.formUnion(parse(nestedMembers))
          }
        }
      }
    }
    return dependencies
  }

  mutating func dependency(from node: VariableDeclSyntax) -> Dependency? {
    guard !isSkipped(node.modifiers),
      let binding = node.bindings.first,
      !node.bindings.contains(where: { $0.initializer != nil }),
      let type = binding.typeAnnotation?.type.trimmed.description
    else { return nil }

    let member = binding.pattern.trimmed.description
    guard let accessorBlock = binding.accessorBlock else {
      return unsupported(
        member, node,
        "is a stored property without an initializer, so the module can't be created with `init()`."
          + " Make it a computed property")
    }
    let effects = accessorBlock.accessors.as(AccessorDeclListSyntax.self)?.compactMap(\.effectSpecifiers).first
    if let effects, let reason = unsupportedEffects(effects.asyncSpecifier, effects.throwsClause) {
      return unsupported(member, node, reason)
    }

    return Dependency(
      dependencyType: .variable,
      name: providerName(node.attributes, node.leadingTrivia),
      type: type,
      block: member,
      parameters: [],
      condition: CompilationCondition(of: node),
      isMainActor: node.attributes.contains(named: "MainActor"))
  }

  mutating func dependency(from node: FunctionDeclSyntax) -> Dependency? {
    guard !isSkipped(node.modifiers),
      let returnType = node.signature.returnClause?.type
    else { return nil }

    let effects = node.signature.effectSpecifiers
    if let reason = unsupportedEffects(effects?.asyncSpecifier, effects?.throwsClause) {
      return unsupported(node.name.text, node, reason)
    }
    if node.genericParameterClause != nil {
      return unsupported(
        node.name.text, node, "is generic, so the registry can't infer its type arguments")
    }

    let parameters: [Dependency.Parameter] = node.signature.parameterClause.parameters.map {
      .init(
        type: getType($0.type),
        name: $0.firstName.trimmed.description,
        value: $0.defaultValue?.value.trimmed.description,
        dependencyId: attributeArgument(Constants.namedProperty, $0.attributes))
    }

    return Dependency(
      dependencyType: .method,
      name: providerName(node.attributes, node.leadingTrivia),
      type: returnType.trimmed.description,
      block: node.name.text,
      parameters: parameters,
      condition: CompilationCondition(of: node),
      isMainActor: node.attributes.contains(named: "MainActor"))
  }

  /// The registry's factories are synchronous and non-throwing, so they can't call effectful members.
  func unsupportedEffects(_ asyncSpecifier: TokenSyntax?, _ throwsClause: ThrowsClauseSyntax?) -> String? {
    switch (asyncSpecifier, throwsClause) {
    case (.some, .some): "is `async throws`, but the registry can't await or handle errors"
    case (.some, nil): "is `async`, but the registry can't await it"
    case (nil, .some): "throws, but the registry can't handle errors"
    case (nil, nil): nil
    }
  }

  mutating func unsupported(_ member: String, _ node: some SyntaxProtocol, _ reason: String) -> Dependency? {
    unsupportedProviders.append(
      UnsupportedProvider(member: member, reason: reason, position: node.positionAfterSkippingLeadingTrivia))
    return nil
  }

  func isSkipped(_ modifiers: DeclModifierListSyntax) -> Bool {
    modifiers.contains { modifier in
      // `private(set)` only restricts the setter, so the getter can still be called.
      guard case .keyword(let keyword) = modifier.name.tokenKind, modifier.detail == nil else { return false }
      return Self.skippedModifiers.contains(keyword)
    }
  }

  /// The provider's name, from the `@Name("...")` macro or a `/// @Name("...")` doc-comment marker,
  /// which names it without importing `ArrowMacros`.
  func providerName(_ attributes: AttributeListSyntax, _ leadingTrivia: Trivia) -> String? {
    attributeArgument(Constants.nameMacro, attributes) ?? docCommentName(leadingTrivia)
  }

  /// Returns the string argument of a `/// @Name("...")` line in the declaration's doc comment.
  func docCommentName(_ trivia: Trivia) -> String? {
    trivia.lazy
      .compactMap { piece -> String? in
        guard case .docLineComment(let comment) = piece else { return nil }
        return comment.dropFirst(3).trimmingCharacters(in: .whitespaces)
      }
      .compactMap { line -> String? in
        let prefix = "@\(Constants.nameMacro)(\""
        guard line.hasPrefix(prefix), line.hasSuffix("\")") else { return nil }
        let name = line.dropFirst(prefix.count).dropLast(2)
        return name.isEmpty || name.contains("\"") ? nil : String(name)
      }
      .first
  }

  /// Returns the string argument of `@<attributeName>("...")`, or the same attribute qualified with
  /// its module: `@Arrow.Named("...")`, `@ArrowMacros.Name("...")`.
  func attributeArgument(
    _ attributeName: String,
    _ attributes: AttributeListSyntax
  ) -> String? {
    attributes
      .compactMap { $0.as(AttributeSyntax.self) }
      .first {
        let name = $0.attributeName.trimmedDescription
        return [attributeName, "Arrow.\(attributeName)", "ArrowMacros.\(attributeName)"].contains(name)
      }?
      .arguments?.as(LabeledExprListSyntax.self)?
      .first?
      .expression
      .as(StringLiteralExprSyntax.self)?
      .segments
      .description
  }

  func getType(
    _ type: TypeSyntax
  ) -> String {
    if let identifierType = type.as(AttributedTypeSyntax.self) {
      return identifierType.baseType.trimmed.description
    }

    return type.trimmed.description
  }
}

extension AttributeListSyntax {
  /// Whether the list contains `@<name>`, with or without arguments.
  func contains(named name: String) -> Bool {
    contains { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == name }
  }
}
