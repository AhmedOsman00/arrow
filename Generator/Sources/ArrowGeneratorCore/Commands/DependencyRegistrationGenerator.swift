import ArgumentParser
import Constants
import Foundation
import PathKit
import SwiftParser
import SwiftSyntax
import XcodeProj

/// Command to generate dependency registration code for Arrow DI framework.
///
/// This command provides the main entry point for the Arrow Generator tool. It supports
/// two modes of operation:
///
/// **Xcode Project Mode** (default):
/// - Parses an Xcode project file to find Swift sources
/// - Generates registration code
/// - Automatically adds the generated file to the Xcode project
///
/// **Swift Package Mode** (`--is-package` flag):
/// - Scans a sources directory for Swift files
/// - Generates registration code in the sources directory
/// - Does not modify any project files
///
/// The tool performs these steps:
/// 1. Discovers Swift files from the specified project/package
/// 2. Parses files to extract dependency modules and dependencies
/// 3. Validates the dependency graph (missing deps, duplicates, cycles)
/// 4. Generates a `dependencies.generated.swift` file with registration code
///
/// Example usage:
/// ```bash
/// # Xcode project
/// arrow generate --xcode-proj-path App.xcodeproj --target-name MyApp
///
/// # Swift package
/// arrow generate --is-package --package-sources-path Sources/MyPackage
/// ```
public struct DependencyRegistrationGenerator: ParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: Constants.generateCommand,
    abstract:
      "Generates a Container extension with dependency registration code by scanning Swift files for dependency modules"
  )

  public init() {}

  /// Enable Swift Package mode instead of Xcode project mode
  @Flag(
    name: .customLong(Constants.isPackageFlag),
    help: "Enable Swift Package mode instead of Xcode project mode")
  var isPackage: Bool = false

  /// The Xcode target name to scan (Xcode mode only)
  @Option(
    name: .customLong(Constants.targetNameArgument),
    help:
      "The Xcode target name to scan for dependency modules (falls back to TARGET_NAME environment variable)"
  )
  var targetName: String?

  /// Path to the .xcodeproj file (Xcode mode only)
  @Option(
    name: .customLong(Constants.xcodeProjPathArgument),
    help: "Path to the .xcodeproj file (falls back to PROJECT_FILE_PATH environment variable)")
  var xcodeProjPath: String?

  /// Paths to Swift Package sources directories (Package mode only)
  @Option(
    name: .customLong(Constants.packageSourcesPathArgument),
    help:
      // swiftlint:disable:next line_length
      "Path to Swift Package sources directory. Use 'path/**' to find all 'Sources' directories recursively, or provide direct path to a Sources directory (can be specified multiple times)"
  )
  var packageSourcesPaths: [String] = []

  public mutating func run() throws {
    guard !isPackage else {
      return try addDependenciesFileToSwiftPackage(packageSourcesPaths: packageSourcesPaths)
    }

    guard let targetName = targetName ?? ProcessInfo.processInfo.environment["TARGET_NAME"] else {
      throw ValidationError.missingArgument(Constants.targetNameArgument)
    }

    guard
      let xcodeProjPath = xcodeProjPath ?? ProcessInfo.processInfo.environment["PROJECT_FILE_PATH"]
    else {
      throw ValidationError.missingArgument(Constants.xcodeProjPathArgument)
    }

    let expandedPaths = packageSourcesPaths.flatMap { expandPath($0) }
    let packagesSwiftFiles =
      expandedPaths
      .map { Path($0) }
      .compactMap { try? $0.recursiveChildren() }
      .flatMap { $0 }
      .filter { $0.extension == "swift" }
      .map { $0.string }

    try addDependenciesFileToXcodeProject(
      xcodeProjPath: xcodeProjPath,
      targetName: targetName,
      packagesSwiftFiles: packagesSwiftFiles)
  }

  /// Generates and adds the dependencies file to an Xcode project
  ///
  /// - Parameters:
  ///   - xcodeProjPath: Path to the .xcodeproj file
  ///   - targetName: Name of the target to scan and add the file to
  ///   - packagesSwiftFiles: Additional Swift files from packages
  /// - Throws: If project parsing, file generation, or project modification fails
  private func addDependenciesFileToXcodeProject(
    xcodeProjPath: String, targetName: String, packagesSwiftFiles: [String]
  ) throws {
    let xcodeProjPath = Path(xcodeProjPath)
    let sourceRoot = xcodeProjPath.parent()
    let xcodeParser = try XcodeFileParser(
      project: XcodeProj(path: xcodeProjPath),
      xcodeProjPath: xcodeProjPath,
      target: targetName)
    let swiftFiles = try xcodeParser.parse() + packagesSwiftFiles
    try generateDependenciesFile(swiftFiles: swiftFiles, outputPath: sourceRoot)
    if try !xcodeParser.isFileAlreadyAdded(path: Constants.generatedFileName) {
      try xcodeParser.addFile(path: Constants.generatedFileName)
    }
  }

  /// Generates the dependencies file for a Swift Package
  ///
  /// - Parameter packageSourcesPaths: Paths to package sources directories
  /// - Throws: If sources cannot be found or file generation fails
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

  /// Core dependency file generation logic
  ///
  /// Performs the complete pipeline:
  /// 1. Parses Swift files to extract dependency modules
  /// 2. Resolves and validates the dependency graph
  /// 3. Generates Swift code using SwiftSyntax
  /// 4. Writes the file to disk
  ///
  /// - Parameters:
  ///   - swiftFiles: Array of Swift file paths to parse
  ///   - outputPath: Directory where the generated file should be written
  /// - Throws: If parsing, validation, or file writing fails
  private func generateDependenciesFile(swiftFiles: [String], outputPath: Path) throws {
    let modules = try parse(files: Set(swiftFiles))
    let buildMap = try DependencyGraphResolver(data: modules).resolveAndValidate()
    let presenter = DependencyFilePresenter(data: modules, dependenciesOrder: buildMap)
    var file = ""
    DependencyFile(presenter: presenter).file.write(to: &file)
    let outputPath = outputPath + Path(Constants.generatedFileName)
    try file.write(toFile: outputPath.string, atomically: true, encoding: .utf8)
  }

  /// Parses Swift files to extract dependency modules
  ///
  /// - Parameter files: Set of Swift file paths to parse
  /// - Returns: Array of discovered dependency modules
  /// - Throws: If file reading or parsing fails
  private func parse(files: Set<String>) throws -> [DependencyModule] {
    return try files.flatMap {
      let path = URL(fileURLWithPath: $0)
      let content = try String(contentsOf: path)
      let tree = Parser.parse(source: content)
      let syntaxVisitor = DependencyModulesParser(viewMode: .all)
      return syntaxVisitor.parse(tree)
    }
  }

  /// Expands a path pattern to find Sources directories
  ///
  /// - If path contains "/**", finds all "Sources" directories recursively under the base path
  /// - Otherwise, returns the path as-is
  ///
  /// - Parameter path: Path or path pattern to expand
  /// - Returns: Array of expanded directory paths
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

    let sourcesDirs =
      children
      .filter { $0.isDirectory && $0.lastComponent == "Sources" }
      .map { $0.string }

    return sourcesDirs
  }

  /// Validation errors for command-line arguments
  enum ValidationError: LocalizedError {
    /// A required command-line argument is missing
    case missingArgument(String)

    var errorDescription: String? {
      switch self {
      case .missingArgument(let arg):
        "Argument: --\(arg) is required."
      }
    }
  }
}
