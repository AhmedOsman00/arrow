import Foundation
import SwiftSyntax

class DependencyFile {
    private let presenter: DependencyFilePresenting
    
    init(_ presenter: DependencyFilePresenting) {
        self.presenter = presenter
    }
    
    private let firstIntend = Trivia.spaces(4)
    private let secondIntend = Trivia.spaces(8)
    private let thirdIntend = Trivia.spaces(12)
    private let colon = TokenSyntax.colonToken(trailingTrivia: .spaces(1))
    private let leftBrace = TokenSyntax.leftBraceToken(trailingTrivia: .newlines(1))
    private let rightBrace = TokenSyntax.rightBraceToken(leadingTrivia: .newlines(1))
    private let leftParen = TokenSyntax.leftParenToken()
    private let rightParen = TokenSyntax.rightParenToken()
    private let comma = TokenSyntax.commaToken(trailingTrivia: .spaces(1))
    private let dot = TokenSyntax.periodToken()
    
    /*
     import UIKit
     import Arrow
     
     extension Container {
     
        func resgister() {
            let module = Module()
     
            self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
                module.provide(resolver.resolved(), a: resolver.resolved(), b: B(), c: resolver.resolved("cType"))
            }
        }
     }
     */
    lazy var file = SourceFileSyntax(statements: .init(createStatements()),
                                     endOfFileToken: .endOfFileToken())
    
    private func createStatements() -> [CodeBlockItemListSyntax.Element] {
        var statements = presenter.fileUiModel.imports.map(importDecl).map {
            CodeBlockItemSyntax(item: .init($0), semicolon: nil)
        }
        statements.append(CodeBlockItemSyntax(item: .decl(extensionDecl.asDecl())))
        return statements
    }
    
    /*
     import ...
     */
    private func importDecl(_ moduleName: String) -> ImportDeclSyntax {
        ImportDeclSyntax(importKeyword: .keyword(.import, trailingTrivia: .space),
                         path: .init([.init(name: .unknown(moduleName, trailingTrivia: .newline))]))
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
        extensionKeyword: .keyword(.extension, leadingTrivia: .newline, trailingTrivia: .space),
        extendedType: IdentifierTypeSyntax(name: TokenSyntax.identifier("Container"),
                                           trailingTrivia: .space),
        memberBlock: MemberBlockSyntax(leftBrace: leftBrace,
                                       members: .init([MemberBlockItemSyntax(decl: registerFuncDecl)]),
                                       rightBrace: rightBrace)
    )

    /*
     func resgister() {
         let module = Module()
     
         self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
             module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
         }
     }
     */
    private lazy var registerFuncDecl = FunctionDeclSyntax(
        leadingTrivia: firstIntend,
        funcKeyword: .keyword(.func, trailingTrivia: .space),
        name: .identifier("register"),
        signature: FunctionSignatureSyntax(
            parameterClause: FunctionParameterClauseSyntax(leftParen: leftParen,
                                                           parameters: [],
                                                           rightParen: .rightParenToken(trailingTrivia: .space))
        ),
        body: CodeBlockSyntax(leftBrace: leftBrace,
                              statements: CodeBlockItemListSyntax(presenter.fileUiModel.modules.map(map) +
                                                                  presenter.fileUiModel.dependencies.map(map)),
                              rightBrace: rightBrace.with(\.leadingTrivia, firstIntend))
    )

    /*
     let module = Module()
     */
    private func map(_ module: String) -> CodeBlockItemSyntax {
        let identifier = IdentifierPatternSyntax(identifier: .identifier(module.lowercased(), trailingTrivia: .space))
        let calledExpression = DeclReferenceExprSyntax(baseName: .identifier(module))
        let value = FunctionCallExprSyntax(calledExpression: calledExpression,
                                           leftParen: leftParen,
                                           arguments: [],
                                           rightParen: rightParen)

        let initializer = InitializerClauseSyntax(equal: .equalToken(trailingTrivia: .space), value: value)
        let pattern = PatternBindingSyntax(pattern: identifier, initializer: initializer)
        let varibale = VariableDeclSyntax(
            bindingSpecifier: .keyword(.let, leadingTrivia: secondIntend, trailingTrivia: .space),
            bindings: .init([pattern]),
            trailingTrivia: .newline
        )
        
        return .init(item: .decl(varibale.asDecl()))
    }

    /*
     self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
         module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     }
     */
    private func map(_ object: DependencyUiModel) -> CodeBlockItemSyntax {
        let function = FunctionCallExprSyntax(leadingTrivia: .newlines(1) + secondIntend,
                                              calledExpression: createResgisterCall(),
                                              leftParen: leftParen,
                                              arguments: .init([createTypeArgument(object.name),
                                                                createNameArgument(object.name),
                                                                createScopeArgument(object.scope)]),
                                              rightParen: rightParen,
                                              trailingClosure: createClosure(object),
                                              trailingTrivia: .newline)

        return .init(item: .expr(function.asExpr()))
    }

    /*
     resolver
     */
    private func createResolver() -> ClosureShorthandParameterListSyntax {
        .init([
            .init(name: .identifier("resolver"), trailingComma: nil)
        ])
    }
    
    /*
     module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     */
    private func createStatements(_ object: DependencyUiModel) -> [CodeBlockItemSyntax] {
        let item = FunctionCallExprSyntax(calledExpression: createModuleFuncCall(module: object.module,
                                                                                 block: object.block).asExpr(),
                                          leftParen: leftParen,
                                          arguments: LabeledExprListSyntax(object.parameters.map(map)),
                                          rightParen: rightParen,
                                          trailingClosure: nil)
        return [CodeBlockItemSyntax(leadingTrivia: thirdIntend, item: .expr(item.asExpr()))]
    }
    
    /*
     container.provide
     */
    private func createModuleFuncCall(module: String, block: String) -> MemberAccessExprSyntax {
        let base = DeclReferenceExprSyntax(baseName: .identifier(module.lowercased()))
        return MemberAccessExprSyntax(base: base,
                                      period: dot,
                                      name: .identifier(block))
    }
    
    /*
     resolver.resolved(), a: resolver.resolved(), b: B()
     */
    private func map(_ arg: DependencyUiModel.Parameter) -> LabeledExprSyntax {
        .init(label: .identifier(arg.name ?? ""),
              colon: arg.name == nil ? nil : colon,
              expression: createResolvedCall(arg.value, arg.id),
              trailingComma: arg.isLast ? nil : comma)
    }
    
    /*
     { resolver in
         module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     }
     */
    private func createClosure(_ object: DependencyUiModel) -> ClosureExprSyntax {
        .init(leftBrace: .leftBraceToken(leadingTrivia: .space, trailingTrivia: .space),
              signature: .init(parameterClause: .simpleInput(createResolver()),
                                                inKeyword: .keyword(.in, leadingTrivia: .space, trailingTrivia: .newline)),
              statements: .init(createStatements(object)),
              rightBrace: rightBrace.with(\.leadingTrivia, .newline + secondIntend))
    }
    
    // name: "Type"
    private func createNameArgument(_ type: String) -> LabeledExprSyntax {
        .init(label: .identifier("name"),
              colon: colon,
              expression: StringLiteralExprSyntax.string(type),
              trailingComma: comma)
    }
    
    // objectScope: .transient
    private func createScopeArgument(_ scope: String) -> LabeledExprSyntax {
        .init(label: .identifier("objectScope"),
              colon: colon,
              expression: MemberAccessExprSyntax(declName: .init(baseName: .identifier(scope))))
    }
    
    // Type.self
    private func createTypeArgument(_ type: String) -> LabeledExprSyntax {
        .init(expression: MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier(type)),
                                                 declName: .init(baseName: .keyword(.self))),
              trailingComma: comma)
    }
    
    // self.register
    private func createResgisterCall() -> MemberAccessExprSyntax {
        .init(base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
              declName: .init(baseName: .identifier("register")))
    }
    
    // resolver.resolved()
    private func createResolvedCall(_ value: String?, _ id: String?) -> ExprSyntax {
        guard let value else {
            let resolved = MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier("resolver")),
                                                  declName: .init(baseName: .identifier("resolved")))
            return FunctionCallExprSyntax(calledExpression: resolved,
                                          leftParen: leftParen,
                                          arguments: id == nil ? [] : [.init(expression: StringLiteralExprSyntax.string(id!))],
                                          rightParen: rightParen).asExpr()
        }
            
        return DeclReferenceExprSyntax(baseName: .identifier(value)).asExpr()
    }
}

extension ExprSyntaxProtocol {
    func asExpr() -> ExprSyntax {
        ExprSyntax(self)
    }
}

extension StringLiteralExprSyntax {
    static func string(_ content: String) -> StringLiteralExprSyntax {
        StringLiteralExprSyntax(openingQuote: .stringQuoteToken(),
                                segments: [.stringSegment(.init(content: .stringSegment(content)))],
                                closingQuote: .stringQuoteToken())
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
