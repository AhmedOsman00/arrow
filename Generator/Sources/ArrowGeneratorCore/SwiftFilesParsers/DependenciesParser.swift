import Constants
import Foundation
import SwiftSyntax

/// Parses dependency declarations within a dependency module.
///
/// This parser extracts individual dependency definitions from the members of a class,
/// struct, or extension. It recognizes:
/// - Computed properties without initializers as dependency providers
/// - Methods with return types as dependency factories
/// - `@Named("...")` attributes for named dependencies
/// - Method parameters and their default values
///
/// Example:
/// ```swift
/// class NetworkModule: SingletonScope {
///     // Parsed as variable dependency
///     var logger: Logger { ConsoleLogger() }
///
///     // Parsed as method dependency with parameters
///     @Named("production")
///     func apiClient(baseURL: String = "https://api.example.com") -> APIClient {
///         APIClient(baseURL: baseURL, logger: resolver.resolve())
///     }
/// }
/// ```
final class DependenciesParser: SyntaxVisitor {
  /// Set of dependencies discovered during parsing
  private var dependencies = Set<Dependency>()

  /// Visits member block items and dispatches to appropriate handlers
  ///
  /// Identifies whether the member is a function or variable and delegates
  /// to the corresponding visit method.
  override func visit(_ node: MemberBlockItemSyntax) -> SyntaxVisitorContinueKind {
    if let function = node.decl.as(FunctionDeclSyntax.self) {
      return visit(function)
    } else if let variable = node.decl.as(VariableDeclSyntax.self) {
      return visit(variable)
    }
    return .skipChildren
  }

  /// Visits variable declarations and extracts dependency information
  ///
  /// Only processes computed properties (variables without initializers) that have
  /// an explicit type annotation. Stored properties are ignored.
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

  /// Visits function declarations and extracts dependency factory information
  ///
  /// Processes methods that have a return type. Extracts the method name, return type,
  /// parameters (including default values), and any `@Named` attributes on the method
  /// or its parameters.
  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let returnType = node.signature.returnClause?.type else { return .skipChildren }

    let name = getName(Constants.nameMacro, node.attributes)
    let parameters: [Dependency.Parameter] = node.signature.parameterClause.parameters.compactMap {
      .init(
        type: $0.type.trimmed.description,
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

  /// Parses a syntax node and returns all discovered dependencies
  ///
  /// - Parameter node: The syntax node to parse (typically a type declaration)
  /// - Returns: Set of dependencies found in the node's members
  func parse<SyntaxType>(_ node: SyntaxType) -> Set<Dependency> where SyntaxType: SyntaxProtocol {
    super.walk(node)
    return dependencies
  }
}

private extension DependenciesParser {
  /// Extracts the name from a `@Named("...")` or `@Name("...")` attribute
  ///
  /// - Parameters:
  ///   - attributeName: The attribute name to search for (e.g., "Named" or "Name")
  ///   - attributes: The attribute list to search
  /// - Returns: The string value from the attribute, or nil if not found
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
}
