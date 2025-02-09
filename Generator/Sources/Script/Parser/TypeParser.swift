import Foundation
import SwiftSyntax

class TypeParser: SyntaxVisitor {
    private var dependencies = Set<DependencyType>()

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let returnType = node.signature.output?.returnType else { return .skipChildren }

        dump(returnType)
        var name: String?
        var type: String
        if let tuple = returnType.as(TupleExprSyntax.self),
            tuple.elementList.count == 2,
            let definedType = tuple.elementList.first,
            let definedName = tuple.elementList.last {
            name = definedName.withoutTrivia().description
            type = definedType.withoutTrivia().description
        } else {
            type = returnType.withoutTrivia().description
        }

        let dependancies: [String] = node.signature.input.parameterList.compactMap {
            guard $0.defaultArgument == nil else { return nil }
            return $0.type?.withoutTrivia().description
        }

        let parameters = node.signature.input.parameterList.map {
            return Parameter(name: $0.firstName?.withoutTrivia().description,
                             value: $0.defaultArgument?.value.withoutTrivia().description)
        }

        let dependencyType = DependencyType(name: name,
                                            type: type,
                                            block: node.identifier.text,
                                            parameters: parameters,
                                            dependencies: dependancies)
        dependencies.insert(dependencyType)
        return super.visit(node)
    }

    func parse<SyntaxType>(_ node: SyntaxType) -> Set<DependencyType> where SyntaxType : SyntaxProtocol {
        super.walk(node)
        return dependencies
    }
}
