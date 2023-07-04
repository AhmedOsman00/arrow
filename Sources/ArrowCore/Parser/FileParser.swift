import Foundation
import SwiftSyntaxParser
import SwiftSyntax

class FileParser: SyntaxVisitor {
    var imports = Set<String>()
    var types = Set<Type>()

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        imports.insert(String(describing: node.path))
        return super.visit(node)
    }
    
//    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
//        dump(node)
//        return super.visit(node)
//    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return createModule(node, node.inheritanceClause, node.identifier.text)
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        return createModule(node, node.inheritanceClause, node.identifier.text)
    }
    
    private func createModule(_ node: DeclSyntaxProtocol,
                              _ inheritanceClause: TypeInheritanceClauseSyntax?,
                              _ name: String) -> SyntaxVisitorContinueKind {
        let scope = inheritanceClause?
            .inheritedTypeCollection
            .compactMap { $0.typeName.withoutTrivia().firstToken?.text }
            .compactMap { Scope.init(rawValue: $0) }
            .first
        guard let scope else { return .skipChildren }
        let parser = Parser(module: name, scope: scope, imports: imports)
        types.formUnion(parser.parse(node))
        return .visitChildren
    }

    func parse<SyntaxType>(_ node: SyntaxType) -> Set<Type> where SyntaxType : SyntaxProtocol {
        super.walk(node)
        return types
    }
}
