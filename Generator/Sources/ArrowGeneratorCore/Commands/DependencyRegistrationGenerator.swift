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
/// The output is a `DependencyRegistry` enum (for example `AnalyticsDependencies`) that apps
/// register with `Container.shared.register(AnalyticsDependencies.self, AppDependencies.self)`.
///
/// **Xcode Project Mode** (default):
/// - Scans the project root (and any `--package-path`) for Swift sources
/// - Generates registration code
/// - Overwrites an existing `dependencies.generated.swift` (the project file is never modified)
///
/// **Swift Package Mode** (`--is-package` flag):
/// - Scans one or more sources directories for Swift files
/// - Generates a `public` registry in the first sources directory
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
      "Generates a DependencyRegistry with dependency registration code by scanning Swift files for dependency modules"
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

  @Option(
    name: .customLong(Constants.externalPathArgument),
    help:
      // swiftlint:disable:next line_length
      "Sources of dependencies provided by another registry (can be specified multiple times). Used for validation only; not generated"
  )
  var externalPaths: [String] = []

  @Option(
    name: .customLong(Constants.registryNameArgument),
    help:
      // swiftlint:disable:next line_length
      "Name of the generated registry type. Defaults to <name>Dependencies, using the first --package-path in package mode or PRODUCT_MODULE_NAME / TARGET_NAME in Xcode mode"
  )
  var registryName: String?

  public mutating func run() throws {
    let logger = Logger(isVerbose: verbose)
    let swiftHandler = SwiftFilesHandler(logger: logger)

    guard !isPackage else {
      guard !packageSourcesPaths.isEmpty else {
        throw ValidationError.missingArgument(Constants.packageSourcesPathArgument)
      }

      let packageName = URL(fileURLWithPath: packageSourcesPaths[0]).standardizedFileURL.lastPathComponent
      let registry = RegistryConfiguration(
        name: registryName ?? RegistryConfiguration.defaultName(for: packageName),
        isPublic: true)
      let packageHandler = PackageHandler(
        swiftHandler: swiftHandler,
        generatedFileName: Constants.generatedFileName,
        logger: logger)
      return try packageHandler.addDependenciesFileToSwiftPackage(
        packageSourcesPaths: packageSourcesPaths,
        externalPaths: externalPaths,
        registry: registry)
    }

    guard
      let projRoot = projRoot ?? ProcessInfo.processInfo.environment["PROJECT_DIR"]
    else {
      throw ValidationError.missingArgument(Constants.projRootArgument)
    }

    let environment = ProcessInfo.processInfo.environment
    let targetName = environment["PRODUCT_MODULE_NAME"] ?? environment["TARGET_NAME"] ?? "App"
    let registry = RegistryConfiguration(
      name: registryName ?? RegistryConfiguration.defaultName(for: targetName),
      isPublic: false)
    let depsExtPath = depsExtPath ?? "\(projRoot)/\(Constants.generatedFileName)"
    let xcodehandler = XcodeProjHandler(
      swiftHandler: swiftHandler,
      generatedFileName: Constants.generatedFileName,
      logger: logger)
    try xcodehandler.addDependenciesFileToXcodeProject(
      projRoot: projRoot,
      packageSourcesPaths: packageSourcesPaths,
      externalPaths: externalPaths,
      depsExtPath: depsExtPath,
      registry: registry)
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
