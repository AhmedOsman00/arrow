import Foundation
import SwiftSyntax

final class MembersParser: SyntaxVisitor {
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
        let name = binding.pattern.trimmed.description
        let dependencyType = Dependency(dependencyType: .variable,
                                        name: type,
                                        type: type,
                                        block: name,
                                        parameters: [])
        dependencies.insert(dependencyType)
        return super.visit(node)
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let returnType = node.signature.returnClause?.type else { return .skipChildren }

//        let name = node.attributes?
//            .compactMap { $0.as(CustomAttributeSyntax.self) }
//            .first { $0.attributeName.description == "Named" }?
//            .argumentList?.first?.expression.as(StringLiteralExprSyntax.self)?
//            .segments
//            .description
        
        let parameters: [DependencyParameter] = node.signature.parameterClause.parameters.compactMap {
            return DependencyParameter(type: $0.type.trimmed.description,
                                       name: $0.firstName.trimmed.description,
                                       value: $0.defaultValue?.value.trimmed.description)
        }
        
        let dependencyType = Dependency(dependencyType: .method,
                                        name: nil,
                                        type: returnType.trimmed.description,
                                        block: node.name.text,
                                        parameters: parameters)
        dependencies.insert(dependencyType)
        return super.visit(node)
    }
    
    func parse<SyntaxType>(_ node: SyntaxType) -> Set<Dependency> where SyntaxType : SyntaxProtocol {
        super.walk(node)
        return dependencies
    }
}
