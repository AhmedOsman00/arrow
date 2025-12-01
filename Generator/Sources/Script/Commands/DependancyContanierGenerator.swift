import Foundation
import ConsoleKit
import PathKit
import SwiftSyntax
import SwiftParser
import XcodeProj

public final class DependancyContanierGenerator: Command {
    public static let name = "generate"
    public let help = "Generate the dependancy contanier"
    
    public init() {}
    
    public struct Signature: CommandSignature {
        public init() {}

        @Option(name: "target-name", help: "")
        var targetName: String?

        @Option(name: "xcode-proj-path", help: "")
        var xcodeProjPath: String?

        @Option(name: "package-name", help: "")
        var packageName: String?

        @Option(name: "package-sources-path", help: "")
        var packageSourcesPath: String?

        @Flag(name: "is-package", help: "")
        var isPackage: Bool
    }

    public func run(using context: CommandContext, signature: Signature) throws {
        if signature.isPackage {
            guard let packageName = signature.packageName ?? ProcessInfo.processInfo.environment["SWIFT_PACKAGE_NAME"] else {
                throw ValidationError.missingArgument("Package name")
            }

            guard let packageSourcesPath = signature.packageSourcesPath ?? ProcessInfo.processInfo.environment["SWIFT_PACKAGE_NAME"] else {
                throw ValidationError.missingArgument("Package name")
            }

            try addDependenciesFileToSwiftPackage(packageName: packageName, packageSourcesPath: packageSourcesPath)
        }

        guard let targetName = signature.targetName ?? ProcessInfo.processInfo.environment["TARGET_NAME"] else {
            throw ValidationError.missingArgument("Target name")
        }

        guard let xcodeProjPath = signature.xcodeProjPath ?? ProcessInfo.processInfo.environment["PROJECT_FILE_PATH"] else {
            throw ValidationError.missingArgument("Project directory")
        }

        try addDependenciesFileToXcodeProject(xcodeProjPath: xcodeProjPath, targetName: targetName)
    }

    func addDependenciesFileToXcodeProject(xcodeProjPath: String, targetName: String) throws {
        let xcodeProjPath = Path(xcodeProjPath)
        let sourceRoot = xcodeProjPath.components.dropLast().joined(separator: "/")
        let xcodeParser = try XCodeParser(project: try XcodeProj(path: xcodeProjPath),
                                          xcodeProjPath: xcodeProjPath,
                                          sourceRoot: sourceRoot,
                                          target: targetName)
        let swiftFiles = try xcodeParser.parse()
        let modules = try parse(files: swiftFiles.asSet())
        let buildMap = try DependencyResolver(data: modules).resolveAndValidate()
        let presenter = DependencyFilePresenter(data: modules, dependenciesOrder: buildMap)
        var file = ""
        DependencyFile(presenter: presenter, registerSuffix: targetName.capitalizeFirstLetter()).file.write(to: &file)
        let url = URL(fileURLWithPath: "\(sourceRoot)/dependencies.generated.swift")
        try file.data(using: .utf8)?.write(to: url)
        let absoluteURLString = url.absoluteString
        if try !xcodeParser.isFileAlreadyAdded(path: absoluteURLString) {
            try xcodeParser.addFile(path: absoluteURLString)
        }
    }

    func addDependenciesFileToSwiftPackage(packageName: String, packageSourcesPath: String) throws {
        
    }

    func parse(files: Set<String>) throws -> [DependencyModule] {
        return try files.flatMap {
            let path = URL(fileURLWithPath: $0)
            let content = try String(contentsOf: path)
            let tree = Parser.parse(source: content)
            let syntaxVisitor = ModuleParser(viewMode: .all)
            return syntaxVisitor.parse(tree)
        }
    }

    enum ValidationError: Error {
        case missingArgument(String)

        var errorDescription: String? {
            switch self {
            case let .missingArgument(arg):
                "Argument: \(arg) is required."
            }
        }
    }
}
