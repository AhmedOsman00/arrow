import Foundation
import ConsoleKit
import PathKit
import SwiftSyntax
import SwiftParser

public final class DependancyContanierGenerator: Command {
    public static var name = "generate"
    public let help = "Generate the dependancy contanier"
    
    public init() {}
    
    public struct Signature: CommandSignature {
        public init() {}

        @Flag(name: "verbose", help: "Show extra logging for debugging purposes")
        var isVerbose: Bool

        @Flag(name: "target-name", help: "Show extra logging for debugging purposes")
        var targetName: Bool

        @Flag(name: "project-dir", help: "Show extra logging for debugging purposes")
        var projectDir: Bool
    }

    public func run(using context: CommandContext, signature: Signature) throws {
        let target = ProcessInfo.processInfo.environment["TARGET_NAME"] ?? ""
        let projectRootPath = ProcessInfo.processInfo.environment["PROJECT_DIR"] ?? ""
        let path = Path(projectRootPath)
        let source = path.components.dropLast().joined(separator: "/")
        let xcodeParser = try XCodeParser(path: path,
                                          source: source,
                                          target: target)
        let swiftFiles = xcodeParser.parse()
        let modules = try parse(files: swiftFiles.asSet())
        print(modules)
//        let buildMap = try DependencyResolver(graph: types).resolve()
//        let presenter = FilePresenter(types: buildMap)
//        var file = ""
//        DependencyFile(presenter).file.write(to: &file)
//        try file.data(using: .utf8)?.write(to: URL(fileURLWithPath: "\(source)/Dependencies.generated.swift"))
//        try xcodeParser.addDependenciesFile()
    }

    func parse(files: Set<String>) throws -> Set<DependencyModule> {
        return try files.flatMap {
            let path = URL(fileURLWithPath: $0)
            let content = try String(contentsOf: path)
            let tree = Parser.parse(source: content)
            let syntaxVisitor = ModuleParser(viewMode: .all)
            return syntaxVisitor.parse(tree)
        }.asSet()
    }
}
