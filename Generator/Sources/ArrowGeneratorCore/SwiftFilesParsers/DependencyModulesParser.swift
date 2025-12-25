import Foundation
import SwiftSyntax

/// Parses Swift source files to identify and extract dependency modules.
///
/// This parser walks the Swift syntax tree to find classes, structs, and extensions
/// that conform to `SingletonScope` or `TransientScope`. For each module found,
/// it collects import statements and delegates dependency parsing to `DependenciesParser`.
///
/// Example usage:
/// ```swift
/// let parser = DependencyModulesParser()
/// let sourceFile = Parser.parse(source: sourceCode)
/// let modules = parser.parse(sourceFile)
/// ```
final class DependencyModulesParser: SyntaxVisitor {
  /// Set of import statements found in the current file
  var imports = Set<String>()

  /// Set of dependency modules discovered during parsing
  var modules = Set<DependencyModule>()

  /// Visits import declarations and collects them for the current module
  override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
    imports.insert(String(describing: node.path))
    return super.visit(node)
  }

  /// Visits extension declarations and creates a module if it conforms to a dependency scope
  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    let identifier = node.extendedType.trimmed.description
    return createModule(.extension, node, node.inheritanceClause, identifier)
  }

  /// Visits class declarations and creates a module if it conforms to a dependency scope
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    return createModule(.class, node, node.inheritanceClause, node.name.text)
  }

  /// Visits struct declarations and creates a module if it conforms to a dependency scope
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    return createModule(.struct, node, node.inheritanceClause, node.name.text)
  }

  /// Creates a dependency module from a type declaration if it conforms to a scope protocol
  ///
  /// - Parameters:
  ///   - type: The module type (class, struct, or extension)
  ///   - node: The declaration node
  ///   - inheritanceClause: The inheritance clause containing protocol conformances
  ///   - name: The name of the type
  /// - Returns: `.skipChildren` if not a dependency module, `.visitChildren` otherwise
  private func createModule(
    _ type: DependencyModule.ModuleType,
    _ node: DeclSyntaxProtocol,
    _ inheritanceClause: InheritanceClauseSyntax?,
    _ name: String
  ) -> SyntaxVisitorContinueKind {
    let scope = inheritanceClause?
      .inheritedTypes
      .compactMap { $0.type.firstToken(viewMode: .sourceAccurate)?.trimmed.text }
      .compactMap { DependencyModule.Scope(rawValue: $0) }
      .first
    guard let scope else { return .skipChildren }
    let types = DependenciesParser(viewMode: .all).parse(node)
    let module = DependencyModule(
      type: type, imports: imports, name: name, scope: scope, types: types)
    modules.insert(module)
    return .visitChildren
  }

  /// Parses a Swift syntax node and returns all discovered dependency modules
  ///
  /// - Parameter node: The syntax node to parse (typically a SourceFileSyntax)
  /// - Returns: Set of dependency modules found in the syntax tree
  func parse<SyntaxType>(_ node: SyntaxType) -> Set<DependencyModule>
  where SyntaxType: SyntaxProtocol {
    super.walk(node)
    return modules
  }
}
