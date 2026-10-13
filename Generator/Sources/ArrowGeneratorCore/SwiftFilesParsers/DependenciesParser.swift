import Constants
import Foundation
import SwiftSyntax

/// Extracts the provider declarations from a module's member block.
///
/// Only direct members are considered, so nested types and local functions are never
/// treated as providers. Members that can't be called on a module instance
/// (`private`, `fileprivate`, `static`, `class`) are skipped.
struct DependenciesParser {
  func parse(_ memberBlock: MemberBlockSyntax) -> Set<Dependency> {
    parse(memberBlock.members)
  }
}

private extension DependenciesParser {
  static let skippedModifiers: Set<Keyword> = [.private, .fileprivate, .static, .class]

  func parse(_ members: MemberBlockItemListSyntax) -> Set<Dependency> {
    members.reduce(into: Set<Dependency>()) { dependencies, member in
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
  }

  func dependency(from node: VariableDeclSyntax) -> Dependency? {
    guard !isSkipped(node.modifiers),
      let binding = node.bindings.first,
      !node.bindings.contains(where: { $0.initializer != nil }),
      let type = binding.typeAnnotation?.type.trimmed.description
    else { return nil }

    return Dependency(
      dependencyType: .variable,
      name: attributeArgument(Constants.nameMacro, node.attributes),
      type: type,
      block: binding.pattern.trimmed.description,
      parameters: [])
  }

  func dependency(from node: FunctionDeclSyntax) -> Dependency? {
    guard !isSkipped(node.modifiers),
      let returnType = node.signature.returnClause?.type
    else { return nil }

    let parameters: [Dependency.Parameter] = node.signature.parameterClause.parameters.map {
      .init(
        type: getType($0.type),
        name: $0.firstName.trimmed.description,
        value: $0.defaultValue?.value.trimmed.description,
        dependencyId: attributeArgument(Constants.namedProperty, $0.attributes))
    }

    return Dependency(
      dependencyType: .method,
      name: attributeArgument(Constants.nameMacro, node.attributes),
      type: returnType.trimmed.description,
      block: node.name.text,
      parameters: parameters)
  }

  func isSkipped(_ modifiers: DeclModifierListSyntax) -> Bool {
    modifiers.contains { modifier in
      guard case .keyword(let keyword) = modifier.name.tokenKind else { return false }
      return Self.skippedModifiers.contains(keyword)
    }
  }

  /// Returns the string argument of `@<attributeName>("...")` or `@Arrow.<attributeName>("...")`.
  func attributeArgument(
    _ attributeName: String,
    _ attributes: AttributeListSyntax
  ) -> String? {
    attributes
      .compactMap { $0.as(AttributeSyntax.self) }
      .first {
        let name = $0.attributeName.trimmedDescription
        return name == attributeName || name == "Arrow.\(attributeName)"
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
