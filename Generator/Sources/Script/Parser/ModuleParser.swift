import Foundation
import SwiftSyntax

final class ModuleParser: SyntaxVisitor {
    var imports = Set<String>()
    var modules = Set<DependencyModule>()
    
    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        imports.insert(String(describing: node.path))
        return super.visit(node)
    }
    
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let identifier = node.extendedType.withoutTrivia().description
        return createModule(.extension, node, node.inheritanceClause, identifier)
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return createModule(.class, node, node.inheritanceClause, node.identifier.text)
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        return createModule(.struct, node, node.inheritanceClause, node.identifier.text)
    }
    
    private func createModule(_ type: DependencyModule.ModuleType,
                              _ node: DeclSyntaxProtocol,
                              _ inheritanceClause: TypeInheritanceClauseSyntax?,
                              _ name: String) -> SyntaxVisitorContinueKind {
        let scope = inheritanceClause?
            .inheritedTypeCollection
            .compactMap { $0.typeName.withoutTrivia().firstToken?.text }
            .compactMap { DependencyModule.Scope.init(rawValue: $0) }
            .first
        guard let scope else { return .skipChildren }
        let types = MembersParser(viewMode: .all).parse(node)
        let module = DependencyModule(type: type, imports: imports, name: name, scope: scope, types: types)
        modules.insert(module)
        return .visitChildren
    }
    
    func parse<SyntaxType>(_ node: SyntaxType) -> Set<DependencyModule> where SyntaxType : SyntaxProtocol {
        super.walk(node)
        return modules
    }
}
