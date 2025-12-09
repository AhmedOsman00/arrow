import Foundation
import Constants
import ArgumentParser
import PathKit
import SwiftSyntax
import SwiftParser
import XcodeProj

public struct DependencyRegistrationGenerator: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: Constants.generateCommand,
        abstract: "Generates a Container extension with dependency registration code by scanning Swift files for dependency modules"
    )

    public init() {}

    @Flag(name: .customLong(Constants.isPackageFlag), help: "Enable Swift Package mode instead of Xcode project mode")
    var isPackage: Bool = false

    @Option(name: .customLong(Constants.targetNameArgument), help: "The Xcode target name to scan for dependency modules (falls back to TARGET_NAME environment variable)")
    var targetName: String?

    @Option(name: .customLong(Constants.xcodeProjPathArgument), help: "Path to the .xcodeproj file (falls back to PROJECT_FILE_PATH environment variable)")
    var xcodeProjPath: String?

    @Option(name: .customLong(Constants.packageSourcesPathArgument), help: "Path to Swift Package sources directory. Use 'path/**' to find all 'Sources' directories recursively, or provide direct path to a Sources directory (can be specified multiple times)")
    var packageSourcesPaths: [String] = []

    public mutating func run() throws {
        guard !isPackage else {
            return try addDependenciesFileToSwiftPackage(packageSourcesPaths: packageSourcesPaths)
        }

        guard let targetName = targetName ?? ProcessInfo.processInfo.environment["TARGET_NAME"] else {
            throw ValidationError.missingArgument(Constants.targetNameArgument)
        }

        guard let xcodeProjPath = xcodeProjPath ?? ProcessInfo.processInfo.environment["PROJECT_FILE_PATH"] else {
            throw ValidationError.missingArgument(Constants.xcodeProjPathArgument)
        }

        let expandedPaths = packageSourcesPaths.flatMap { expandPath($0) }
        let packagesSwiftFiles = expandedPaths
            .map { Path($0) }
            .compactMap { try? $0.recursiveChildren() }
            .flatMap { $0 }
            .filter { $0.extension == "swift" }
            .map { $0.string }

        try addDependenciesFileToXcodeProject(xcodeProjPath: xcodeProjPath,
                                              targetName: targetName,
                                              packagesSwiftFiles: packagesSwiftFiles)
    }

    private func addDependenciesFileToXcodeProject(xcodeProjPath: String, targetName: String, packagesSwiftFiles: [String]) throws {
        let xcodeProjPath = Path(xcodeProjPath)
        let sourceRoot = xcodeProjPath.parent()
        let xcodeParser = try XcodeFileParser(project: XcodeProj(path: xcodeProjPath),
                                              xcodeProjPath: xcodeProjPath,
                                              target: targetName)
        let swiftFiles = try xcodeParser.parse() + packagesSwiftFiles
        try generateDependenciesFile(swiftFiles: swiftFiles, outputPath: sourceRoot)
        if try !xcodeParser.isFileAlreadyAdded(path: Constants.generatedFileName) {
            try xcodeParser.addFile(path: Constants.generatedFileName)
        }
    }

    private func addDependenciesFileToSwiftPackage(packageSourcesPaths: [String]) throws {
        guard let packageSourcesPath = packageSourcesPaths.first else {
            throw ValidationError.missingArgument(Constants.packageSourcesPathArgument)
        }

        let sourcesPath = Path(packageSourcesPath)
        let swiftFiles = try sourcesPath.recursiveChildren()
            .filter { $0.extension == "swift" }
            .map { $0.string }
        try generateDependenciesFile(swiftFiles: swiftFiles, outputPath: sourcesPath)
    }

    private func generateDependenciesFile(swiftFiles: [String], outputPath: Path) throws {
        let modules = try parse(files: Set(swiftFiles))
        let buildMap = try DependencyGraphResolver(data: modules).resolveAndValidate()
        let presenter = DependencyFilePresenter(data: modules, dependenciesOrder: buildMap)
        var file = ""
        DependencyFile(presenter: presenter).file.write(to: &file)
        let outputPath = outputPath + Path(Constants.generatedFileName)
        try file.write(toFile: outputPath.string, atomically: true, encoding: .utf8)
    }

    private func parse(files: Set<String>) throws -> [DependencyModule] {
        return try files.flatMap {
            let path = URL(fileURLWithPath: $0)
            let content = try String(contentsOf: path)
            let tree = Parser.parse(source: content)
            let syntaxVisitor = DependencyModulesParser(viewMode: .all)
            return syntaxVisitor.parse(tree)
        }
    }

    /// Expands a path that may contain /** pattern or returns the path as-is
    /// - If path contains "/**", finds all "Sources" directories recursively under the base path
    /// - Otherwise, returns the path as-is
    private func expandPath(_ path: String) -> [String] {
        // If no /** pattern, return the path as-is
        guard path.contains("/**") else {
            return [path]
        }

        // Extract base path by removing /**
        let basePath = path.replacingOccurrences(of: "/**", with: "")
        let basePathKit = Path(basePath)

        // Find all "Sources" directories recursively
        guard let children = try? basePathKit.recursiveChildren() else {
            return []
        }

        let sourcesDirs = children
            .filter { $0.isDirectory && $0.lastComponent == "Sources" }
            .map { $0.string }

        return sourcesDirs
    }

    enum ValidationError: LocalizedError {
        case missingArgument(String)

        var errorDescription: String? {
            switch self {
            case let .missingArgument(arg):
                "Argument: --\(arg) is required."
            }
        }
    }
}
