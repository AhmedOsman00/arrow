import Foundation
import SwiftSyntax

class ArrowParser: SyntaxVisitor {
    private var types = Set<Type>()
    private let module: String
    private let scope: Scope
    private let imports: Set<String>

    init(viewMode: SyntaxTreeViewMode, module: String, scope: Scope, imports: Set<String>) {
        self.module = module
        self.scope = scope
        self.imports = imports
        super.init(viewMode: viewMode)
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let name = node.signature.output?.returnType.withoutTrivia().description else { return .skipChildren }

        let dependancies: [String] = node.signature.input.parameterList.compactMap {
            guard $0.defaultArgument == nil else { return nil }
            return $0.type?.withoutTrivia().description
        }
        let parameters = node.signature.input.parameterList.map {
            return Parameter(name: $0.firstName?.withoutTrivia().description,
                             value: $0.defaultArgument?.value.withoutTrivia().description)
        }
        let type = Type(module: module,
             scope: scope,
             imports: imports,
             name: name,
             block: node.identifier.text,
             parameters: parameters,
             dependancies: dependancies)
        types.insert(type)
        return super.visit(node)
    }

    func parse<SyntaxType>(_ node: SyntaxType) -> Set<Type> where SyntaxType : SyntaxProtocol {
        super.walk(node)
        return types
    }
}
