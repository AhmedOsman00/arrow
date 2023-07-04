import Foundation
import SwiftSyntax
import SwiftParser

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
            let tree = Parser.parse(source: content)
            let syntaxVisitor = FileParser(viewMode: .all)
            return syntaxVisitor.parse(tree)
        }.asSet()
    }
}
