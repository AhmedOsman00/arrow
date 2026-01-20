import Constants
import Foundation
import SwiftSyntax

final class DependenciesParser: SyntaxVisitor {
  private var dependencies = Set<Dependency>()

  override func visit(_ node: MemberBlockItemSyntax) -> SyntaxVisitorContinueKind {
    if let function = node.decl.as(FunctionDeclSyntax.self) {
      return visit(function)
    } else if let variable = node.decl.as(VariableDeclSyntax.self) {
      return visit(variable)
    }
    return .skipChildren
  }

  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let binding = node.bindings.first,
      !node.bindings.contains(where: { $0.initializer != nil }),
      let type = binding.typeAnnotation?.type.trimmed.description
    else { return .skipChildren }

    let block = binding.pattern.trimmed.description
    let name = getName(Constants.nameMacro, node.attributes)
    let dependencyType = Dependency(
      dependencyType: .variable,
      name: name,
      type: type,
      block: block,
      parameters: [])
    dependencies.insert(dependencyType)
    return super.visit(node)
  }

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let returnType = node.signature.returnClause?.type else { return .skipChildren }

    let name = getName(Constants.nameMacro, node.attributes)
    let parameters: [Dependency.Parameter] = node.signature.parameterClause.parameters.compactMap {
      return .init(
        type: getType($0.type),
        name: $0.firstName.trimmed.description,
        value: $0.defaultValue?.value.trimmed.description,
        dependencyId: getName(Constants.namedProperty, $0.attributes))
    }

    let dependencyType = Dependency(
      dependencyType: .method,
      name: name,
      type: returnType.trimmed.description,
      block: node.name.text,
      parameters: parameters)
    dependencies.insert(dependencyType)
    return super.visit(node)
  }

  func parse<SyntaxType>(_ node: SyntaxType) -> Set<Dependency> where SyntaxType: SyntaxProtocol {
    super.walk(node)
    return dependencies
  }
}

private extension DependenciesParser {
  func getName(
    _ attributeName: String,
    _ attributes: AttributeListSyntax
  ) -> String? {
    attributes
      .compactMap { $0.as(AttributeSyntax.self) }
      .first { $0.attributeName.description.contains(attributeName) }?
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
