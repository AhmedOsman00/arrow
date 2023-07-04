import Foundation
import SwiftSyntax
import SwiftSyntaxParser

extension Array where Element: Hashable {
    func asSet() -> Set<Element> {
        Set(self)
    }
}

final class FilesParser {
    func parse(files: Set<String>) throws -> Set<Type> {
        return try files.flatMap {
            let path = URL(fileURLWithPath: $0)
            let content = try String(contentsOf: path)
            let tree = try SyntaxParser.parse(source: content)
            let syntaxVisitor = FileParser()
            return syntaxVisitor.parse(tree)
        }.asSet()
    }
}
