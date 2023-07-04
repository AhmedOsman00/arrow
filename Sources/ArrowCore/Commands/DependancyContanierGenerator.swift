import Foundation
import ConsoleKit
import PathKit
import SwiftSyntax

public final class DependancyContanierGenerator: Command {
    public static var name = "generate"
    public let help = "Generate the dependancy contanier"
    
    public init() {}
    
    public struct Signature: CommandSignature {
        public init() {}
        
        @Flag(name: "verbose", help: "Show extra logging for debugging purposes")
        var isVerbose: Bool

        @Argument(name: "project-file")
        var projectFile: String
        
        @Argument(name: "main-target")
        var mainTarget: String
    }

    public func run(using context: CommandContext, signature: Signature) throws {
        let path = Path(signature.projectFile)
        let source = path.components.dropLast().joined(separator: "/")
        let xcodeParser = try XCodeParser(path: path,
                                          source: source,
                                          target: signature.mainTarget)
        
        let swiftFiles = xcodeParser.parse()
        
        let types = try FilesParser().parse(files: swiftFiles.asSet())
        let buildMap = try DependencyResolver(graph: types).resolve()
        let presenter = FilePresenter(types: buildMap)
        var file = ""
        DependencyFile(presenter).file.write(to: &file)
        try file.data(using: .utf8)?.write(to: URL(fileURLWithPath: "\(source)/Dependencies.generated.swift"))
        try xcodeParser.addDependenciesFile(projectFile: signature.projectFile)
    }
}
