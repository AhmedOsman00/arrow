import Foundation
import SwiftSyntax

final class DependencyModulesParser: SyntaxVisitor {
    var imports = Set<String>()
    var modules = Set<DependencyModule>()

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        imports.insert(String(describing: node.path))
        return super.visit(node)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let identifier = node.extendedType.trimmed.description
        return createModule(.extension, node, node.inheritanceClause, identifier)
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return createModule(.class, node, node.inheritanceClause, node.name.text)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        return createModule(.struct, node, node.inheritanceClause, node.name.text)
    }

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

    func parse<SyntaxType>(_ node: SyntaxType) -> Set<DependencyModule>
    where SyntaxType: SyntaxProtocol {
        super.walk(node)
        return modules
    }
}
