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

  @Flag(
    name: .customShort(Constants.verbose),
    help: "Enable Swift Package mode instead of Xcode project mode")
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
      "Path to Swift Package sources directory. Use path/** to find all 'Sources' directories recursively, or provide direct path to a Sources directory (can be specified multiple times)"
  )
  var packageSourcesPaths: [String] = []

  public mutating func run() throws {
    let logger = Logger(isVerbose: verbose)
    let swiftHandler = SwiftFilesHandler(logger: logger)

    guard !isPackage else {
      guard let packageSourcesPath = packageSourcesPaths.first else {
        throw ValidationError.missingArgument(Constants.packageSourcesPathArgument)
      }

      let packageHandler = PackageHandler(
        swiftHandler: swiftHandler,
        generatedFileName: Constants.generatedFileName,
        logger: logger)
      return try packageHandler.addDependenciesFileToSwiftPackage(packageSourcesPath: packageSourcesPath)
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
