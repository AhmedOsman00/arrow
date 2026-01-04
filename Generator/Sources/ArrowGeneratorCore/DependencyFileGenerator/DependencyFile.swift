import Foundation
import SwiftSyntax

/// Generates Swift source code for dependency registration using SwiftSyntax.
///
/// This class builds a complete Swift source file containing:
/// - Import statements for all required modules
/// - A `Container` extension with a `register()` method
/// - Module instantiations
/// - Dependency registration calls in topological order
///
/// The generated code follows this structure:
/// ```swift
/// import UIKit
/// import Arrow
///
/// extension Container {
///   func register() {
///     let module = Module()
///
///     self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
///       module.provide(
///         resolver.resolve(B.self, name: "B"),
///         a: resolver.resolve(A.self, name: "A")
///       )
///     }
///   }
/// }
/// ```
class DependencyFile {
    /// The presenter providing UI models for code generation
    private let presenter: DependencyFilePresenting

    /// Initializes the code generator with a presenter
    ///
    /// - Parameter presenter: Presenter containing the file UI model
    init(presenter: DependencyFilePresenting) {
        self.presenter = presenter
    }

    // Indentation and formatting tokens
    private let firstIntend = Trivia.spaces(2)
    private let secondIntend = Trivia.spaces(4)
    private let thirdIntend = Trivia.spaces(6)
    private let fourthIntend = Trivia.spaces(8)
    private let colon = TokenSyntax.colonToken(trailingTrivia: .spaces(1))
    private let leftBrace = TokenSyntax.leftBraceToken(trailingTrivia: .newlines(1))
    private let rightBrace = TokenSyntax.rightBraceToken(leadingTrivia: .newlines(1))
    private let leftParen = TokenSyntax.leftParenToken()
    private let rightParen = TokenSyntax.rightParenToken()
    private let comma = TokenSyntax.commaToken(trailingTrivia: .spaces(1))
    private let dot = TokenSyntax.periodToken()

    /// The complete generated Swift source file
    /// ```swift
    /// import UIKit
    /// import Arrow
    ///
    /// extension Container {
    ///  func resgister() {
    ///    let module = Module()
    ///
    ///    self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
    ///      module.provide(
    ///        resolver.resolve(B.self, name: "B"),
    ///        a: resolver.resolve(A.self, name: "A"),
    ///        c: resolver.resolve(C.self, name: "cType")
    ///      )
    ///    }
    ///  }
    /// }
    /// ```
    /// This lazily computed property builds the entire syntax tree for the
    /// generated `dependencies.generated.swift` file.
    lazy var file = SourceFileSyntax(
        statements: .init(createStatements()),
        endOfFileToken: .endOfFileToken())

    private func createStatements() -> [CodeBlockItemListSyntax.Element] {
        var statements = presenter.fileUiModel.imports.map(importDecl).map {
            CodeBlockItemSyntax(item: .init($0), semicolon: nil)
        }
        statements.append(CodeBlockItemSyntax(item: .decl(extensionDecl.asDecl())))
        return statements
    }

    /// ```swift
    /// import UIKit
    /// ```
    private func importDecl(_ moduleName: String) -> ImportDeclSyntax {
        ImportDeclSyntax(
            importKeyword: .keyword(.import, trailingTrivia: .space),
            path: .init([.init(name: .unknown(moduleName, trailingTrivia: .newline))]))
    }

    /// ```swift
    /// extension Container {
    ///  func resgister() {
    ///    let module = Module()
    ///
    ///    self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
    ///      module.provide(
    ///        resolver.resolve(B.self, name: "B"),
    ///        a: resolver.resolve(A.self, name: "A"),
    ///        c: resolver.resolve(C.self, name: "cType")
    ///      )
    ///    }
    ///  }
    /// }
    /// ```
    private lazy var extensionDecl = ExtensionDeclSyntax(
        extensionKeyword: .keyword(.extension, leadingTrivia: .newline, trailingTrivia: .space),
        extendedType: IdentifierTypeSyntax(
            name: TokenSyntax.identifier("Container"),
            trailingTrivia: .space),
        memberBlock: MemberBlockSyntax(
            leftBrace: leftBrace,
            members: .init([MemberBlockItemSyntax(decl: registerFuncDecl)]),
            rightBrace: rightBrace)
    )

    /// ```swift
    ///  func resgister() {
    ///    let module = Module()
    ///
    ///    self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
    ///      module.provide(
    ///        resolver.resolve(B.self, name: "B"),
    ///        a: resolver.resolve(A.self, name: "A"),
    ///        c: resolver.resolve(C.self, name: "cType")
    ///      )
    ///    }
    ///  }
    /// ```
    private lazy var registerFuncDecl = FunctionDeclSyntax(
        leadingTrivia: firstIntend,
        funcKeyword: .keyword(.func, trailingTrivia: .space),
        name: .identifier("register"),
        signature: FunctionSignatureSyntax(
            parameterClause: FunctionParameterClauseSyntax(
                leftParen: leftParen,
                parameters: [],
                rightParen: .rightParenToken(trailingTrivia: .space))
        ),
        body: CodeBlockSyntax(
            leftBrace: leftBrace,
            statements: CodeBlockItemListSyntax(
                presenter.fileUiModel.modules.map(map) + presenter.fileUiModel.dependencies.map(map)),
            rightBrace: rightBrace.with(\.leadingTrivia, firstIntend))
    )

    /// ```swift
    /// let module = Module()
    /// ```
    private func map(_ module: String) -> CodeBlockItemSyntax {
        let identifier = IdentifierPatternSyntax(
            identifier: .identifier(module.lowercased(), trailingTrivia: .space))
        let calledExpression = DeclReferenceExprSyntax(baseName: .identifier(module))
        let value = FunctionCallExprSyntax(
            calledExpression: calledExpression,
            leftParen: leftParen,
            arguments: [],
            rightParen: rightParen)

        let initializer = InitializerClauseSyntax(
            equal: .equalToken(trailingTrivia: .space), value: value)
        let pattern = PatternBindingSyntax(pattern: identifier, initializer: initializer)
        let varibale = VariableDeclSyntax(
            bindingSpecifier: .keyword(.let, leadingTrivia: secondIntend, trailingTrivia: .space),
            bindings: .init([pattern]),
            trailingTrivia: .newline
        )

        return .init(item: .decl(varibale.asDecl()))
    }

    /// ```swift
    /// self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
    ///  module.provide(
    ///    resolver.resolve(B.self, name: "B"),
    ///    a: resolver.resolve(A.self, name: "A"),
    ///    c: resolver.resolve(C.self, name: "cType")
    ///  )
    /// }
    /// ```
    private func map(_ object: DependencyUiModel) -> CodeBlockItemSyntax {
        let args = [
            createTypeArgument(object.type),
            createNameArgument(object.name),
            createScopeArgument(object.scope),
        ]
        let function = FunctionCallExprSyntax(
            leadingTrivia: .newlines(1) + secondIntend,
            calledExpression: createResgisterCall(),
            leftParen: leftParen,
            arguments: .init(args),
            rightParen: rightParen,
            trailingClosure: createClosure(object),
            trailingTrivia: .newline)

        return .init(item: .expr(function.asExpr()))
    }

    /// ```swift
    /// resolver
    /// ```
    private func createResolver() -> ClosureShorthandParameterListSyntax {
        .init([
            .init(name: .identifier("resolver"), trailingComma: nil)
        ])
    }

    /// ```swift
    ///  module.provide(
    ///    resolver.resolve(B.self, name: "B"),
    ///    a: resolver.resolve(A.self, name: "A"),
    ///    c: resolver.resolve(C.self, name: "cType")
    ///  )
    /// ```
    private func createFunctionCallExprSyntax(_ object: DependencyUiModel) -> [CodeBlockItemSyntax] {
        let item = FunctionCallExprSyntax(
            calledExpression: createModuleFuncCall(
                module: object.module,
                block: object.block
            ).asExpr(),
            leftParen: object.isFunc ? leftParen : nil,
            arguments: object.isFunc ? LabeledExprListSyntax(object.parameters.map(map)) : [],
            rightParen: object.isFunc ? rightParen : nil,
            trailingClosure: nil)
        return [CodeBlockItemSyntax(leadingTrivia: thirdIntend, item: .expr(item.asExpr()))]
    }

    /// ```swift
    /// container.provide
    /// ```
    private func createModuleFuncCall(module: String, block: String) -> MemberAccessExprSyntax {
        let base = DeclReferenceExprSyntax(baseName: .identifier(module.lowercased()))
        return MemberAccessExprSyntax(
            base: base,
            period: dot,
            name: .identifier(block))
    }

    /// ```swift
    /// resolver.resolve(B.self, name: "B"),
    /// a: resolver.resolve(A.self, name: "A"),
    /// c: resolver.resolve(C.self, name: "cType")
    /// ```
    private func map(_ arg: DependencyUiModel.Parameter) -> LabeledExprSyntax {
        .init(
            leadingTrivia: .newline.appending(fourthIntend),
            label: .identifier(arg.label ?? ""),
            colon: arg.label == nil ? nil : colon,
            expression: createResolveCall(type: arg.type, id: arg.id),
            trailingComma: arg.isLast ? nil : comma,
            trailingTrivia: arg.isLast ? .newline.appending(thirdIntend) : nil
        )
    }

    /// ```swift
    /// { resolver in
    ///  module.provide(
    ///    resolver.resolve(B.self, name: "B"),
    ///    a: resolver.resolve(A.self, name: "A"),
    ///    c: resolver.resolve(C.self, name: "cType")
    ///  )
    /// }
    /// ```
    private func createClosure(_ object: DependencyUiModel) -> ClosureExprSyntax {
        .init(
            leftBrace: .leftBraceToken(leadingTrivia: .space, trailingTrivia: .space),
            signature: .init(
                parameterClause: .simpleInput(createResolver()),
                inKeyword: .keyword(.in, leadingTrivia: .space, trailingTrivia: .newline)),
            statements: .init(createFunctionCallExprSyntax(object)),
            rightBrace: rightBrace.with(\.leadingTrivia, .newline + secondIntend))
    }

    /// ```swift
    /// name: "Type"
    /// ```
    private func createNameArgument(_ type: String) -> LabeledExprSyntax {
        .init(
            label: .identifier("name"),
            colon: colon,
            expression: StringLiteralExprSyntax.string(type),
            trailingComma: comma)
    }

    /// ```swift
    /// objectScope: .transient
    /// ```
    private func createScopeArgument(_ scope: String) -> LabeledExprSyntax {
        .init(
            label: .identifier("objectScope"),
            colon: colon,
            expression: MemberAccessExprSyntax(declName: .init(baseName: .identifier(scope))))
    }

    /// ```swift
    /// Type.self
    /// ```
    private func createTypeArgument(_ type: String) -> LabeledExprSyntax {
        .init(
            expression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier(type)),
                declName: .init(baseName: .keyword(.self))),
            trailingComma: comma)
    }

    /// ```swift
    /// self.register
    /// ```
    private func createResgisterCall() -> MemberAccessExprSyntax {
        .init(
            base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
            declName: .init(baseName: .identifier("register")))
    }

    /// ```swift
    /// resolver.resolve(B.self, name: "B")
    /// ```
    private func createResolveCall(type: String, id: String) -> ExprSyntax {
        let resolve = MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("resolver")),
            declName: .init(baseName: .identifier("resolve")))
        let args: LabeledExprListSyntax = [
            LabeledExprSyntax(
                expression: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier(type)),
                    declName: .init(baseName: .keyword(.self))
                ),
                trailingComma: comma
            ),
            LabeledExprSyntax(
                label: .identifier("name"),
                colon: colon,
                expression: StringLiteralExprSyntax.string(id)),
        ]

        return FunctionCallExprSyntax(
            calledExpression: resolve,
            leftParen: leftParen,
            arguments: args,
            rightParen: rightParen
        ).asExpr()
    }
}

extension ExprSyntaxProtocol {
    func asExpr() -> ExprSyntax {
        ExprSyntax(self)
    }
}

extension StringLiteralExprSyntax {
    static func string(_ content: String) -> StringLiteralExprSyntax {
        StringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
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
