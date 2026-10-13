import ArgumentParser
import Constants
import Foundation
import PathKit
import SwiftParser
import SwiftSyntax

/// Command to generate dependency registration code for Arrow DI framework.
///
/// This command provides the main entry point for the Arrow Generator tool. It supports
/// two modes of operation:
///
/// **Xcode Project Mode** (default):
/// - Scans the project root (and any `--package-path`) for Swift sources
/// - Generates registration code
/// - Overwrites an existing `dependencies.generated.swift` (the project file is never modified)
///
/// **Swift Package Mode** (`--is-package` flag):
/// - Scans one or more sources directories for Swift files
/// - Generates registration code in the first sources directory
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
/// arrow generate --proj-root /path/to/App
///
/// # Swift package
/// arrow generate --is-package --package-path Sources/MyPackage
/// ```
public struct DependencyRegistrationGenerator: ParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: Constants.generateCommand,
    abstract:
      "Generates a Container extension with dependency registration code by scanning Swift files for dependency modules"
  )

  public init() {}

  @Flag(
    name: .customShort(Constants.verbose),
    help: "Enable verbose logging")
  var verbose: Bool = false

  @Flag(
    name: .customLong(Constants.isPackageFlag),
    help: "Enable Swift Package mode instead of Xcode project mode")
  var isPackage: Bool = false

  @Option(
    name: .customLong(Constants.extensionPathArgument),
    help: "Path to the dependencies.generated.swift file (falls back to PROJECT_DIR environment variable)")
  var depsExtPath: String?

  @Option(
    name: .customLong(Constants.projRootArgument),
    help: "Root path of the project (falls back to PROJECT_DIR environment variable)")
  var projRoot: String?

  @Option(
    name: .customLong(Constants.packageSourcesPathArgument),
    help:
      // swiftlint:disable:next line_length
      "Path to a Swift Package sources directory (can be specified multiple times). In package mode the generated file is written to the first path"
  )
  var packageSourcesPaths: [String] = []

  public mutating func run() throws {
    let logger = Logger(isVerbose: verbose)
    let swiftHandler = SwiftFilesHandler(logger: logger)

    guard !isPackage else {
      guard !packageSourcesPaths.isEmpty else {
        throw ValidationError.missingArgument(Constants.packageSourcesPathArgument)
      }

      let packageHandler = PackageHandler(
        swiftHandler: swiftHandler,
        generatedFileName: Constants.generatedFileName,
        logger: logger)
      return try packageHandler.addDependenciesFileToSwiftPackage(packageSourcesPaths: packageSourcesPaths)
    }

    guard
      let projRoot = projRoot ?? ProcessInfo.processInfo.environment["PROJECT_DIR"]
    else {
      throw ValidationError.missingArgument(Constants.projRootArgument)
    }

    let depsExtPath = depsExtPath ?? "\(projRoot)/\(Constants.generatedFileName)"
    let xcodehandler = XcodeProjHandler(
      swiftHandler: swiftHandler,
      generatedFileName: Constants.generatedFileName,
      logger: logger)
    try xcodehandler.addDependenciesFileToXcodeProject(
      projRoot: projRoot,
      packageSourcesPaths: packageSourcesPaths,
      depsExtPath: depsExtPath)
  }

  enum ValidationError: LocalizedError {
    case missingArgument(String)

    var errorDescription: String? {
      switch self {
      case .missingArgument(let arg):
        "Argument: --\(arg) is required."
      }
    }
  }
}
