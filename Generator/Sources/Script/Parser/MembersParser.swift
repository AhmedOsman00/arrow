import Foundation
import SwiftSyntax

final class MembersParser: SyntaxVisitor {
    private var dependencies = Set<Dependency>()
    
    override func visit(_ node: MemberDeclListItemSyntax) -> SyntaxVisitorContinueKind {
        if let function = node.decl.as(FunctionDeclSyntax.self) {
            return visit(function)
        } else if let variable = node.decl.as(VariableDeclSyntax.self) {
            return visit(variable)
        }
        return .skipChildren
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let binding = node.bindings.first,
              let type = binding.typeAnnotation?.type.withoutTrivia().description
        else { return .skipChildren }
        let name = binding.pattern.withoutTrivia().description
        let dependencyType = Dependency(dependencyType: .variable,
                                        name: type,
                                        type: type,
                                        block: name,
                                        parameters: [],
                                        dependencies: [])
        dependencies.insert(dependencyType)
        return super.visit(node)
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let returnType = node.signature.output?.returnType else { return .skipChildren }
        
        let name = node.attributes?
            .compactMap { $0.as(CustomAttributeSyntax.self) }
            .first { $0.attributeName.description == "Named" }?
            .argumentList?.first?.expression.as(StringLiteralExprSyntax.self)?
            .segments
            .description

        let type = returnType.withoutTrivia().description
        let dependancies: [String] = node.signature.input.parameterList.compactMap {
            guard $0.defaultArgument == nil else { return nil }
            return $0.type?.withoutTrivia().description
        }
        
        let parameters = node.signature.input.parameterList.map {
            return Parameter(name: $0.firstName?.withoutTrivia().description,
                             value: $0.defaultArgument?.value.withoutTrivia().description)
        }
        
        let dependencyType = Dependency(dependencyType: .method,
                                        name: name,
                                        type: type,
                                        block: node.identifier.text,
                                        parameters: parameters,
                                        dependencies: dependancies)
        dependencies.insert(dependencyType)
        return super.visit(node)
    }
    
    func parse<SyntaxType>(_ node: SyntaxType) -> Set<Dependency> where SyntaxType : SyntaxProtocol {
        super.walk(node)
        return dependencies
    }
}
