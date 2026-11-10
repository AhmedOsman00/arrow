import Foundation
import SwiftSyntax

final class DependencyModulesParser: SyntaxVisitor {
  var imports = Set<String>()
  var conditionalImports = [String: String]()
  var modules = Set<DependencyModule>()
  /// Unsupported members, with the name of the module that declares them
  var unsupportedProviders = [(module: String, provider: UnsupportedProvider)]()

  override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
    // `import struct Foo.Bar` imports a single declaration, and its path ends in that declaration's
    // name rather than a submodule, so the generated file imports the whole module `Foo` instead.
    let name =
      node.importKindSpecifier == nil
      ? node.path.trimmedDescription
      : node.path.first?.name.text ?? node.path.trimmedDescription
    if let condition = CompilationCondition(of: node).expression {
      conditionalImports[name] = condition
    } else {
      imports.insert(name)
    }
    return super.visit(node)
  }

  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    let identifier = node.extendedType.trimmed.description
    return createModule(.extension, node, node.attributes, node.memberBlock, node.inheritanceClause, identifier)
  }

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let name = qualifiedName(node.name.text, node) else { return .skipChildren }
    return createModule(.class, node, node.attributes, node.memberBlock, node.inheritanceClause, name)
  }

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let name = qualifiedName(node.name.text, node) else { return .skipChildren }
    return createModule(.struct, node, node.attributes, node.memberBlock, node.inheritanceClause, name)
  }

  /// `Inner` declared in `Outer` -> `Outer.Inner`. Returns nil for a type declared in a function,
  /// accessor or closure body, which the registry can't reach.
  private func qualifiedName(_ name: String, _ node: some SyntaxProtocol) -> String? {
    var components = [name]
    var ancestor = node.parent
    while let current = ancestor {
      let isBody = current.is(CodeBlockSyntax.self) || current.is(AccessorBlockSyntax.self)
      if isBody || current.is(ClosureExprSyntax.self) {
        return nil
      }
      if let outer = current.as(ClassDeclSyntax.self) {
        components.insert(outer.name.text, at: 0)
      } else if let outer = current.as(StructDeclSyntax.self) {
        components.insert(outer.name.text, at: 0)
      } else if let outer = current.as(EnumDeclSyntax.self) {
        components.insert(outer.name.text, at: 0)
      } else if let outer = current.as(ActorDeclSyntax.self) {
        components.insert(outer.name.text, at: 0)
      } else if let outer = current.as(ExtensionDeclSyntax.self) {
        components.insert(outer.extendedType.trimmedDescription, at: 0)
      }
      ancestor = current.parent
    }
    return components.joined(separator: ".")
  }

  private func createModule(
    _ type: DependencyModule.ModuleType,
    _ node: some DeclSyntaxProtocol,
    _ attributes: AttributeListSyntax,
    _ memberBlock: MemberBlockSyntax,
    _ inheritanceClause: InheritanceClauseSyntax?,
    _ name: String
  ) -> SyntaxVisitorContinueKind {
    // Use the last component so qualified conformances like `Arrow.SingletonScope` are detected.
    let scope = inheritanceClause?
      .inheritedTypes
      .compactMap { $0.type.trimmedDescription.split(separator: ".").last.map(String.init) }
      .compactMap { DependencyModule.Scope(rawValue: $0) }
      .first
    // Not a module, but it may still declare nested modules.
    guard let scope else { return .visitChildren }
    var parser = DependenciesParser()
    let types = parser.parse(memberBlock)
    unsupportedProviders += parser.unsupportedProviders.map { (name, $0) }
    let module = DependencyModule(
      type: type, imports: imports, name: name, scope: scope, types: types,
      condition: CompilationCondition(of: node), isMainActor: attributes.contains(named: "MainActor"))
    modules.insert(module)
    return .visitChildren
  }

  /// - Parameter fileName: The path reported in diagnostics.
  /// - Throws: `ParserError.unsupportedProviders` if a module declares a provider the registry can't call.
  func parse<SyntaxType>(_ node: SyntaxType, fileName: String = "") throws -> Set<DependencyModule>
  where SyntaxType: SyntaxProtocol {
    super.walk(node)
    if !unsupportedProviders.isEmpty {
      let converter = SourceLocationConverter(fileName: fileName, tree: node)
      throw ParserError.unsupportedProviders(
        unsupportedProviders.map { module, provider in
          let location = converter.location(for: provider.position)
          return "\(fileName):\(location.line):\(location.column): error: "
            + "`\(module).\(provider.member)` \(provider.reason)."
        })
    }
    // Imports can appear anywhere in the file, so attach them once the whole file is walked.
    let conditionalImports = conditionalImports.filter { !imports.contains($0.key) }
    return modules.reduce(into: []) { result, module in
      result.insert(
        DependencyModule(
          type: module.type, imports: imports, name: module.name, scope: module.scope, types: module.types,
          condition: module.condition, conditionalImports: conditionalImports, isMainActor: module.isMainActor))
    }
  }
}
