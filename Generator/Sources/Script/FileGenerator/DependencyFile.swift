import Foundation
import SwiftSyntax

class DependencyFile {
    private let presenter: DependencyFilePresenting
    
    init(_ presenter: DependencyFilePresenting) {
        self.presenter = presenter
    }
    
    private let colon = TokenSyntax.colonToken(trailingTrivia: .spaces(1))
    private let leftBrace = TokenSyntax.leftBraceToken(trailingTrivia: .newlines(1))
    private let rightBrace = TokenSyntax.rightBraceToken(leadingTrivia: .newlines(1))
    private let leftParen = TokenSyntax.leftParenToken()
    private let rightParen = TokenSyntax.rightParenToken()
    private let comma = TokenSyntax.commaToken(trailingTrivia: .spaces(1))
    private let dot = TokenSyntax.periodToken()
    
    /*
     import UIKit
     import Swinject
     
     extension Container {
     
        func resgister() {
            let module = Module()
     
            self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
                module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
            }
        }
     }
     */
    lazy var file = SourceFileSyntax(statements: .init(createStatements()),
                                     eofToken: .eof())
    
    private func createStatements() -> [CodeBlockItemListSyntax.Element] {
        var statements = presenter.imports.map(importDecl).map {
            CodeBlockItemSyntax(
                item: .init($0),
                semicolon: nil,
                errorTokens: nil)
        }
        statements.append(CodeBlockItemSyntax(item: .decl(extensionDecl.asDecl())))
        return statements
    }
    
    /*
     import ...
     */
    private func importDecl(_ moduleName: String) -> ImportDeclSyntax {
        ImportDeclSyntax(
            importTok: .importKeyword(trailingTrivia: .spaces(1)),
            path: .init([
                .init(name: .unknown(moduleName,
                                     trailingTrivia: .newlines(1)))
            ]))
    }
    
    /*
     extension Container {

        func resgister() {
            let module = Module()
     
             self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
                 module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
             }
        }
     }
     */
    private lazy var extensionDecl = ExtensionDeclSyntax(
        extensionKeyword: .extensionKeyword(leadingTrivia: .newlines(1),
                                            trailingTrivia: .spaces(1)),
        extendedType: SimpleTypeIdentifierSyntax(name: TokenSyntax.identifier("Container"),
                                                 trailingTrivia: .spaces(1)),
        members: MemberDeclBlockSyntax(
            leftBrace: .leftBraceToken(trailingTrivia: .newlines(2)),
            members: .init([MemberDeclListItemSyntax(decl: registerFuncDecl,
                                                     semicolon: nil)]),
            rightBrace: rightBrace))

    /*
     func resgister() {
         let module = Module()
     
         self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
             module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
         }
     }
     */
    private lazy var registerFuncDecl = FunctionDeclSyntax(
        leadingTrivia: .spaces(4),
        funcKeyword: .funcKeyword(trailingTrivia: .spaces(1)),
        identifier: .identifier("register"),
        signature: FunctionSignatureSyntax(input: ParameterClauseSyntax(
                                           leftParen: leftParen,
                                           parameterList: .init([]),
                                           rightParen: .rightParenToken(trailingTrivia: .spaces(1)))),
        body: CodeBlockSyntax(leftBrace: leftBrace,
                              statements: CodeBlockItemListSyntax(presenter.moduleNames.map(map) +
                                                                  presenter.objects.map(map)),
                              rightBrace: rightBrace.withLeadingTrivia(.newlines(1) + .spaces(4)))
    )

    /*
     let module = Module()
     */
    private func map(_ module: String) -> CodeBlockItemSyntax {
        let identifier = IdentifierPatternSyntax(identifier: .identifier(module.lowercased(), trailingTrivia: .spaces(1)))
        let calledExpression = IdentifierExprSyntax(identifier: .identifier(module))
        let value = FunctionCallExprSyntax(
            calledExpression: calledExpression,
            leftParen: leftParen,
            argumentList: .init([]),
            rightParen: rightParen)

        let initializer = InitializerClauseSyntax(
            equal: .equalToken(trailingTrivia: .spaces(1)),
            value: value)

        let pattern = PatternBindingSyntax(pattern: identifier,
                                           initializer: initializer)
        let varibale = VariableDeclSyntax(
            letOrVarKeyword: TokenSyntax.letKeyword(
                leadingTrivia: .spaces(8),
                trailingTrivia: .spaces(1)),
            bindings: .init([pattern]))
        
        return CodeBlockItemSyntax(item: .decl(varibale.asDecl()))
    }

    /*
     self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
         module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     }
     */
    private func map(_ object: Object) -> CodeBlockItemSyntax {
        let function = FunctionCallExprSyntax(leadingTrivia: .newlines(2) + .spaces(8),
                                              calledExpression: createResgisterCall(),
                                              leftParen: leftParen,
                                              argumentList: .init([createTypeArgument(object.name),
                                                                   createNameArgument(object.name),
                                                                   createScopeArgument(object.scope)]),
                                              rightParen: rightParen,
                                              trailingClosure: createClosure(object))

        return CodeBlockItemSyntax(item: .expr(function.asExpr()))
    }

    /*
     resolver
     */
    private func createResolver() -> ClosureParamListSyntax {
        ClosureParamListSyntax([
            ClosureParamSyntax(
            name: .identifier("resolver"),
            trailingComma: nil)
        ])
    }
    
    /*
     module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     */
    private func createStatements(_ object: Object) -> [CodeBlockItemSyntax] {
        let item = FunctionCallExprSyntax(calledExpression: createModuleFuncCall(module: object.module,
                                                                                 block: object.block).asExpr(),
                                          leftParen: leftParen,
                                          argumentList: TupleExprElementListSyntax(object.args.map(map)),
                                          rightParen: rightParen,
                                          trailingClosure: nil,
                                          additionalTrailingClosures: nil)
        return [CodeBlockItemSyntax(leadingTrivia: .spaces(12), item: .expr(item.asExpr()))]
    }
    
    /*
     container.provide
     */
    private func createModuleFuncCall(module: String, block: String) -> MemberAccessExprSyntax {
        let base = IdentifierExprSyntax(
            identifier: .identifier(module.lowercased()),
            declNameArguments: nil)
        return MemberAccessExprSyntax(base: base,
                               dot: dot,
                               name: .identifier(block))
    }
    
    /*
     resolver.resolved(), a: resolver.resolved(), b: B()
     */
    private func map(_ arg: Arg) -> TupleExprElementSyntax {
        TupleExprElementSyntax(
            label: TokenSyntax.identifier(arg.name ?? ""),
            colon: arg.name == nil ? nil : colon,
            expression: createResolvedCall(arg.value),
            trailingComma: arg.comma ? comma : nil)
    }
    
    /*
     { resolver in
         module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     }
     */
    private func createClosure(_ object: Object) -> ClosureExprSyntax {
        ClosureExprSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space, trailingTrivia: .space),
            signature: ClosureSignatureSyntax(
                attributes: nil,
                capture: nil,
                input: .simpleInput(createResolver()),
                asyncKeyword: nil,
                throwsTok: nil,
                output: nil,
                inTok: .inKeyword(leadingTrivia: .spaces(1), trailingTrivia: .newlines(1))),
            statements: CodeBlockItemListSyntax(createStatements(object)),
            rightBrace: rightBrace.withLeadingTrivia(.newlines(1) + .spaces(8)))
    }
    
    // name: "Type"
    private func createNameArgument(_ type: String) -> TupleExprElementSyntax {
        TupleExprElementSyntax(
            label: TokenSyntax.identifier("name"),
            colon: colon,
            expression: ExprSyntax(SyntaxFactory.makeStringLiteralExpr(type)),
            trailingComma: comma)
    }
    
    // objectScope: .transient
    private func createScopeArgument(_ scope: String) -> TupleExprElementSyntax {
        let dotScope = MemberAccessExprSyntax(
            base: nil,
            dot: dot,
            name: .identifier(scope),
            declNameArguments: nil)
        
        return TupleExprElementSyntax(label: TokenSyntax.identifier("objectScope"),
                                      colon: colon,
                                      expression: dotScope,
                                      trailingComma: nil)
    }
    
    // Type.self
    private func createTypeArgument(_ type: String) -> TupleExprElementSyntax {
        TupleExprElementSyntax(
            label: nil,
            colon: nil,
            expression: MemberAccessExprSyntax(
                base: IdentifierExprSyntax(
                    identifier: TokenSyntax.identifier(type),
                    declNameArguments: nil),
                dot: dot,
                name: TokenSyntax.selfKeyword(),
                declNameArguments: nil),
            trailingComma: comma)
    }
    
    // self.register
    private func createResgisterCall() -> MemberAccessExprSyntax {
        MemberAccessExprSyntax(
            base: IdentifierExprSyntax(identifier: .selfKeyword(),
                                       declNameArguments: nil).asExpr(),
            dot: dot,
            name: .identifier("register"),
            declNameArguments: nil)
    }
    
    // resolver.resolved()
    private func createResolvedCall(_ value: String?) -> ExprSyntax {
        guard let value else {
            let resolver = IdentifierExprSyntax(identifier: TokenSyntax.identifier("resolver"))
            
            let resolved = MemberAccessExprSyntax(
                base: resolver,
                dot: dot,
                name: .identifier("resolved"),
                declNameArguments: nil)
            
            return FunctionCallExprSyntax(
                calledExpression: resolved,
                leftParen: leftParen,
                argumentList: TupleExprElementListSyntax([]),
                rightParen: rightParen,
                trailingClosure: nil,
                additionalTrailingClosures: nil).asExpr()
        }
            
        return IdentifierExprSyntax(
            identifier: TokenSyntax.identifier(value),
            declNameArguments: nil).asExpr()
    }
}

extension ExprSyntaxProtocol {
    func asExpr() -> ExprSyntax {
        ExprSyntax(self)
    }
}

extension VariableDeclSyntax {
    func asDecl() -> DeclSyntax {
        DeclSyntax(self)
    }
}

extension ExtensionDeclSyntax {
    func asDecl() -> DeclSyntax {
        DeclSyntax(self)
    }
}

extension PatternSyntaxProtocol {
    func asPattern() -> PatternSyntax {
        PatternSyntax(self)
    }
}
