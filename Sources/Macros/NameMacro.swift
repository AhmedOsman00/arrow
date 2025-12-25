import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

public struct NameMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax,
                                 providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        return []
    }
}

@main
struct NamePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        NameMacro.self,
    ]
}
