import Foundation
import Constants
import ConsoleKit
import PathKit
import SwiftSyntax
import SwiftParser
import XcodeProj

public final class DependencyRegistrationGenerator: Command {
    public static let name = Constants.generateCommand
    public let help = "Generates a Container extension with dependency registration code by scanning Swift files for dependency modules"

    public init() {}

    public struct Signature: CommandSignature {
        public init() {}

        @Option(name: Constants.targetNameArgument, help: "The Xcode target name to scan for dependency modules (falls back to TARGET_NAME environment variable)")
        var targetName: String?

        @Option(name: Constants.xcodeProjPathArgument, help: "Path to the .xcodeproj file (falls back to PROJECT_FILE_PATH environment variable)")
        var xcodeProjPath: String?

        @Option(name: Constants.packageNameArgument, help: "The Swift Package name to use as the registration suffix")
        var packageName: String?

        @Option(name: Constants.packageSourcesPathArgument, help: "Path to the Swift Package sources directory to scan")
        var packageSourcesPath: String?

        @Flag(name: Constants.isPackageFlag, help: "Enable Swift Package mode instead of Xcode project mode")
        var isPackage: Bool
    }

    public func run(using context: CommandContext, signature: Signature) throws {
        guard !signature.isPackage else {
            guard let packageName = signature.packageName else {
                throw ValidationError.missingArgument("Package name")
            }

            guard let packageSourcesPath = signature.packageSourcesPath else {
                throw ValidationError.missingArgument("Package sources path")
            }

            return try addDependenciesFileToSwiftPackage(packageName: packageName, packageSourcesPath: packageSourcesPath)
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
        let sourceRoot = xcodeProjPath.parent()
        let xcodeParser = try XcodeFileParser(project: try XcodeProj(path: xcodeProjPath),
                                              xcodeProjPath: xcodeProjPath,
                                              target: targetName)
        let swiftFiles = try xcodeParser.parse()
        try generateDependenciesFile(swiftFiles: swiftFiles, registerSuffix: targetName, outputPath: sourceRoot)
        if try !xcodeParser.isFileAlreadyAdded(path: Constants.generatedFileName) {
            try xcodeParser.addFile(path: Constants.generatedFileName)
        }
    }

    func addDependenciesFileToSwiftPackage(packageName: String, packageSourcesPath: String) throws {
        let sourcesPath = Path(packageSourcesPath)
        let swiftFiles = try sourcesPath.recursiveChildren()
            .filter { $0.extension == "swift" }
            .map { $0.string }
        try generateDependenciesFile(swiftFiles: swiftFiles, registerSuffix: packageName, outputPath: sourcesPath)
    }

    func generateDependenciesFile(swiftFiles: [String], registerSuffix: String, outputPath: Path) throws {
        let modules = try parse(files: Set(swiftFiles))
        let buildMap = try DependencyGraphResolver(data: modules).resolveAndValidate()
        let presenter = DependencyFilePresenter(data: modules, dependenciesOrder: buildMap)
        var file = ""
        DependencyFile(presenter: presenter, registerSuffix: registerSuffix.capitalizeFirstLetter()).file.write(to: &file)
        let outputPath = outputPath + Path(Constants.generatedFileName)
        try file.write(toFile: outputPath.string, atomically: true, encoding: .utf8)
    }

    func parse(files: Set<String>) throws -> [DependencyModule] {
        return try files.flatMap {
            let path = URL(fileURLWithPath: $0)
            let content = try String(contentsOf: path)
            let tree = Parser.parse(source: content)
            let syntaxVisitor = DependencyModulesParser(viewMode: .all)
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
