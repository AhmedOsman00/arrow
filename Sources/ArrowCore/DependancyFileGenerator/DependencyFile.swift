import Foundation
import SwiftSyntax

class DependencyFile {
    private let presenter: FilePresenter
    
    init(_ presenter: FilePresenter) {
        self.presenter = presenter
    }
    
    private let colon = SyntaxFactory.makeColonToken(trailingTrivia: .spaces(1))
    private let leftBrace = SyntaxFactory.makeLeftBraceToken(trailingTrivia: .newlines(1))
    private let rightBrace = SyntaxFactory.makeRightBraceToken(leadingTrivia: .newlines(1))
    private let leftParen = SyntaxFactory.makeLeftParenToken()
    private let rightParen = SyntaxFactory.makeRightParenToken()
    private let comma = SyntaxFactory.makeCommaToken(trailingTrivia: .spaces(1))
    private let dot = SyntaxFactory.makePeriodToken()
    
    /*
     import UIKit
     import Swinject
     
     extension Container {
     
        func resgister() {
            let module = Module()
     
            self.register(Type.self, name: "Type") { resolver in
                container.provide(resolver.resolved(), a: resolver.resolved(), b: B())
            }
            .inObjectScope(.container)
        }
     }
     */
    lazy var file = SourceFileSyntax { builder in
        presenter.imports.map(importDecl).forEach {
            builder.addStatement(SyntaxFactory.makeCodeBlockItem(
                item: Syntax($0),
                semicolon: nil,
                errorTokens: nil))
        }
        builder.addStatement(CodeBlockItemSyntax { builder in
            builder.useItem(Syntax(extensionDecl))
        })
    }
    
    /*
     import ...
     */
    private func importDecl(_ moduleName: String) -> ImportDeclSyntax {
        ImportDeclSyntax { builder in
            builder.useImportTok(SyntaxFactory.makeImportKeyword(trailingTrivia: .spaces(1)))
            builder.addPathComponent(AccessPathComponentSyntax { builder in
                builder.useName(SyntaxFactory.makeUnknown(moduleName, trailingTrivia: .newlines(1)))
            })
        }
    }
    
    /*
     extension Container {

        func resgister() {
            let module = Module()
     
             self.register(Type.self, name: "Type") { resolver in
                 container.provide(resolver.resolved(), a: resolver.resolved(), b: B())
             }
             .inObjectScope(.container)
        }
     }
     */
    private lazy var extensionDecl = ExtensionDeclSyntax { builder in
        builder.useExtensionKeyword(SyntaxFactory.makeExtensionKeyword(leadingTrivia: .newlines(1), trailingTrivia: .spaces(1)))
        builder.useExtendedType(SyntaxFactory.makeTypeIdentifier("Container", trailingTrivia: .spaces(1)))
        builder.useMembers(SyntaxFactory.makeMemberDeclBlock(
            leftBrace: SyntaxFactory.makeLeftBraceToken(trailingTrivia: .newlines(2)),
            members: SyntaxFactory.makeMemberDeclList([SyntaxFactory.makeMemberDeclListItem(
                decl: DeclSyntax(registerFuncDecl),
                semicolon: nil)]),
            rightBrace: rightBrace))
    }
    
    /*
     func resgister() {
         let module = Module()
     
         self.register(Type.self, name: "Type") { resolver in
             container.provide(resolver.resolved(), a: resolver.resolved(), b: B())
         }
         .inObjectScope(.container)
     }
     */
    private lazy var registerFuncDecl = FunctionDeclSyntax { builder in
        builder.useFuncKeyword(SyntaxFactory.makeFuncKeyword(trailingTrivia: .spaces(1)))
        builder.useIdentifier(SyntaxFactory.makeIdentifier("register"))
        builder.useSignature(SyntaxFactory.makeFunctionSignature(
            input: SyntaxFactory.makeParameterClause(
                leftParen: leftParen,
                parameterList: SyntaxFactory.makeBlankFunctionParameterList(),
                rightParen: SyntaxFactory.makeRightParenToken(trailingTrivia: .spaces(1))),
            asyncOrReasyncKeyword: nil,
            throwsOrRethrowsKeyword: nil,
            output: nil))
        builder.useBody(SyntaxFactory.makeCodeBlock(
            leftBrace: SyntaxFactory.makeLeftBraceToken(),
            statements: SyntaxFactory.makeCodeBlockItemList(
                presenter.moduleNames.map(map) +
                presenter.getObjects().map(map)
            ),
            rightBrace: SyntaxFactory.makeRightBraceToken(leadingTrivia: .newlines(1) + .spaces(4))))
    }.withLeadingTrivia(.spaces(4))
    
    /*
     let module = Module()
     */
    private func map(_ module: String) -> CodeBlockItemSyntax {
        let identifier = IdentifierPatternSyntax { builder in
            builder.useIdentifier(SyntaxFactory.makeIdentifier(module.lowercased(), trailingTrivia: .spaces(1)))
        }
        let asd = IdentifierExprSyntax { builder in
            builder.useIdentifier(SyntaxFactory.makeIdentifier(module))
        }.asExpr()
        let initx = FunctionCallExprSyntax { builder in
            builder.useLeftParen(leftParen)
            builder.useRightParen(rightParen)
            builder.useCalledExpression(asd)
        }.asExpr()
        let initializer = InitializerClauseSyntax { builder in
            builder.useEqual(SyntaxFactory.makeEqualToken(trailingTrivia: .spaces(1)))
            builder.useValue(initx)
        }
        let pattern = PatternBindingSyntax { builder in
            builder.usePattern(identifier.asPattern())
            builder.useInitializer(initializer)
        }
        let varibale = VariableDeclSyntax { builder in
            builder.useLetOrVarKeyword(SyntaxFactory.makeLetKeyword(leadingTrivia: [.newlines(1), .spaces(8)],
                                                                    trailingTrivia: .spaces(1)))
            builder.addBinding(pattern)
        }
        return CodeBlockItemSyntax { builder in
            builder.useItem(Syntax(varibale))
        }
    }

    /*
     self.register(Type.self, name: "Type") { resolver in
         container.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     }
     .inObjectScope(.container)
     */
    private func map(_ object: Object) -> CodeBlockItemSyntax {
        let closureCall = MemberAccessExprSyntax { builder in
            builder.useBase(createRegisterStatment(object).asExpr())
            builder.useDot(SyntaxFactory.makePeriodToken(leadingTrivia: .spaces(8)))
            builder.useName(SyntaxFactory.makeIdentifier("inObjectScope"))
        }
        
        let dotScope = SyntaxFactory.makeMemberAccessExpr(
            base: nil,
            dot: dot,
            name: SyntaxFactory.makeIdentifier(object.scope),
            declNameArguments: nil)
        
        let function = FunctionCallExprSyntax { builder in
            builder.useRightParen(rightParen)
            builder.useLeftParen(leftParen)
            builder.useCalledExpression(closureCall.asExpr())
            builder.addArgument(SyntaxFactory.makeTupleExprElement(
                label: nil,
                colon: nil,
                expression: dotScope.asExpr(),
                trailingComma: nil))
        }
        return CodeBlockItemSyntax { builder in
            builder.useItem(Syntax(function))
        }
    }
    
    /*
     self.register(Type.self, name: "Type") { resolver in
         container.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     }
     */
    private func createRegisterStatment(_ object: Object) -> FunctionCallExprSyntax {
        FunctionCallExprSyntax { builder in
            builder.useCalledExpression(createResgisterCall().asExpr())
            builder.useLeftParen(leftParen)
            builder.addArgument(createTypeArgument(object.name))
            builder.addArgument(createNameArgument(object.name))
            builder.useRightParen(SyntaxFactory.makeRightParenToken(trailingTrivia: .spaces(1)))
            builder.useTrailingClosure(createClosure(object))
        }.withLeadingTrivia(.newlines(2) + .spaces(8))
    }

    /*
     resolver
     */
    private func createResolver() -> ClosureParamSyntax {
        SyntaxFactory.makeClosureParam(
            name: SyntaxFactory.makeIdentifier("resolver"),
            trailingComma: nil)
    }
    
    /*
     container.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     */
    private func createStatements(_ object: Object) -> [CodeBlockItemSyntax] {
        [
            CodeBlockItemSyntax { builder in
                builder.useItem(Syntax(SyntaxFactory.makeFunctionCallExpr(
                    calledExpression: createModuleFuncCall(module: object.module,
                                                           block: object.block).asExpr(),
                    leftParen: leftParen,
                    argumentList: SyntaxFactory.makeTupleExprElementList(object.args.map(map)),
                    rightParen: SyntaxFactory.makeRightParenToken(trailingTrivia: .newlines(1).appending(.spaces(8))),
                    trailingClosure: nil,
                    additionalTrailingClosures: nil)))
            }.withLeadingTrivia(.spaces(12))
        ]
    }
    
    private func createModuleFuncCall(module: String, block: String) -> MemberAccessExprSyntax {
        MemberAccessExprSyntax { builder in
            builder.useBase(SyntaxFactory.makeIdentifierExpr(
                identifier: SyntaxFactory.makeIdentifier(module.lowercased()),
                declNameArguments: nil).asExpr())
            builder.useDot(dot)
            builder.useName(SyntaxFactory.makeIdentifier(block))
        }
    }
    
    /*
     (resolver.resolved(), a: resolver.resolved(), b: B())
     */
    private func map(_ arg: Arg) -> TupleExprElementSyntax {
        SyntaxFactory.makeTupleExprElement(
            label: SyntaxFactory.makeIdentifier(arg.name ?? ""),
            colon: arg.name == nil ? nil : colon,
            expression: createResolvedCall(arg.value),
            trailingComma: arg.comma ? nil : comma)
    }
    
    /*
     { resolver in
         container.provide(resolver.resolved(), a: resolver.resolved(), b: B())
     }
     */
    private func createClosure(_ object: Object) -> ClosureExprSyntax {
        SyntaxFactory.makeClosureExpr(
            leftBrace: SyntaxFactory.makeLeftBraceToken(trailingTrivia: .spaces(1)),
            signature: SyntaxFactory.makeClosureSignature(
                attributes: nil,
                capture: nil,
                input: Syntax(createResolver()),
                asyncKeyword: nil,
                throwsTok: nil,
                output: nil,
                inTok: SyntaxFactory.makeInKeyword(leadingTrivia: .spaces(1), trailingTrivia: .newlines(1))),
            statements: SyntaxFactory.makeCodeBlockItemList(createStatements(object)),
            rightBrace: SyntaxFactory.makeRightBraceToken(trailingTrivia: .newlines(1)))
    }
    
    // name: "Type"
    private func createNameArgument(_ type: String) -> TupleExprElementSyntax {
        SyntaxFactory.makeTupleExprElement(
            label: SyntaxFactory.makeIdentifier("name"),
            colon: SyntaxFactory.makeColonToken(trailingTrivia: .spaces(1)),
            expression: ExprSyntax(SyntaxFactory.makeStringLiteralExpr(type)),
            trailingComma: nil)
    }
    
    // Type.self
    private func createTypeArgument(_ type: String) -> TupleExprElementSyntax {
        SyntaxFactory.makeTupleExprElement(
            label: nil,
            colon: nil,
            expression: ExprSyntax(SyntaxFactory.makeMemberAccessExpr(
                base: ExprSyntax(SyntaxFactory.makeIdentifierExpr(
                    identifier: SyntaxFactory.makeIdentifier(type),
                    declNameArguments: nil)),
                dot: SyntaxFactory.makePeriodToken(),
                name: SyntaxFactory.makeSelfKeyword(),
                declNameArguments: nil)),
            trailingComma: comma)
    }
    
    // self.register
    private func createResgisterCall() -> MemberAccessExprSyntax {
        SyntaxFactory.makeMemberAccessExpr(
            base: SyntaxFactory.makeIdentifierExpr(
                identifier: SyntaxFactory.makeSelfKeyword(),
                declNameArguments: nil).asExpr(),
            dot: SyntaxFactory.makePeriodToken(),
            name: SyntaxFactory.makeIdentifier("register"),
            declNameArguments: nil)
    }
    
    // resolver.resolved()
    private func createResolvedCall(_ value: String?) -> ExprSyntax {
        guard let value else {
            let resolver = IdentifierExprSyntax { builder in
                builder.useIdentifier(SyntaxFactory.makeIdentifier("resolver"))
            }.asExpr()
            
            let resolved = SyntaxFactory.makeMemberAccessExpr(
                base: resolver,
                dot: dot,
                name: SyntaxFactory.makeIdentifier("resolved"),
                declNameArguments: nil).asExpr()
            
            return SyntaxFactory.makeFunctionCallExpr(
                calledExpression: resolved,
                leftParen: leftParen,
                argumentList: SyntaxFactory.makeBlankTupleExprElementList(),
                rightParen: rightParen,
                trailingClosure: nil,
                additionalTrailingClosures: nil).asExpr()
        }
            
        return ExprSyntax(SyntaxFactory.makeIdentifierExpr(
            identifier: SyntaxFactory.makeIdentifier(value),
            declNameArguments: nil))
    }
}

extension ExprSyntaxProtocol {
    func asExpr() -> ExprSyntax {
        ExprSyntax(self)
    }
}

extension PatternSyntaxProtocol {
    func asPattern() -> PatternSyntax {
        PatternSyntax(self)
    }
}
