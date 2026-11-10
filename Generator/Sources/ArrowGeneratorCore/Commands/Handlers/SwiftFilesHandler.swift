import Foundation
import PathKit
import SwiftParser
import SwiftSyntax

protocol SwiftFilesHandlerProtocol {
  func getAllSwiftFiles(in swiftDirs: [String]) throws -> Set<String>
  func parseSwiftFiles(_ swiftFiles: Set<String>) throws -> [DependencyModule]
  func generateDependenciesFile(
    modules: [DependencyModule],
    externalModules: [DependencyModule],
    registry: RegistryConfiguration
  ) throws -> String
}

extension SwiftFilesHandlerProtocol {
  /// Parses the files under `paths` and `externalPaths` and generates the registry file.
  ///
  /// Files under `externalPaths` belong to other registries: their providers count for validation
  /// and ordering but aren't emitted, even when an external path is nested inside one of `paths`.
  /// So do files in a Swift package nested inside one of `paths`, which generates its own registry.
  func generateDependenciesFile(
    paths: [String],
    externalPaths: [String],
    registry: RegistryConfiguration
  ) throws -> String {
    let externalFiles = try getAllSwiftFiles(in: externalPaths)
    let files = try getAllSwiftFiles(in: paths).subtracting(externalFiles)
    let nestedPackageFiles = SwiftFilesHandler.nestedPackageFiles(files, roots: paths)
    return try generateDependenciesFile(
      modules: parseSwiftFiles(files.subtracting(nestedPackageFiles)),
      externalModules: parseSwiftFiles(externalFiles.union(nestedPackageFiles)),
      registry: registry)
  }
}

final class SwiftFilesHandler: SwiftFilesHandlerProtocol {
  /// Directories that never contain project sources; skipped when walking the file system.
  static let skippedDirectories: Set<String> = [".build", "DerivedData", "Pods", "Carthage"]

  let logger: Logging

  init(logger: Logging) {
    self.logger = logger
  }

  func getAllSwiftFiles(in swiftDirs: [String]) throws -> Set<String> {
    logger.log("🔍 Starting to search for Swift files in \(swiftDirs.count) directories")
    logger.log("Directories: \(swiftDirs.joined(separator: ", "))")

    let swiftFiles =
      swiftDirs
      .map { Path($0) }
      .compactMap { path -> [String]? in
        do {
          return try swiftFilesUsingGit(in: path)
        } catch {
          logger.log("⚠️  Failed to get files using git in: \(error.localizedDescription)")
        }

        do {
          return try swiftFilesRecursively(in: path)
        } catch {
          logger.log("⚠️  Failed to read directory: \(path.string) - \(error.localizedDescription)")
          return nil
        }
      }
      .flatMap { $0 }
      // Overlapping inputs (e.g. `.` and `Package/Sources`) must not yield the same file twice.
      .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
      .asSet()

    logger.log("✅ Found \(swiftFiles.count) Swift files")
    swiftFiles.sorted().forEach { logger.log("  - \($0)") }

    return swiftFiles
  }

  func swiftFilesUsingGit(in repoPath: Path) throws -> [String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "*.swift"]
    process.currentDirectoryURL = URL(fileURLWithPath: repoPath.string)

    let pipe = Pipe()
    process.standardOutput = pipe

    let errorPipe = Pipe()
    process.standardError = errorPipe

    try process.run()

    // Read before waiting: a full pipe buffer would otherwise block git and hang forever.
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let errorMessage = String(data: errorData, encoding: .utf8)
      throw ValidationError.git(repoPath.string, errorMessage ?? "")
    }

    let output = String(data: data, encoding: .utf8) ?? ""

    return
      output
      .split(separator: "\0")
      .map { "\(repoPath)/\($0)" }
      // Tracked files deleted from the working tree are still listed by git.
      .filter { FileManager.default.fileExists(atPath: $0) }
  }

  func swiftFilesRecursively(in path: Path) throws -> [String] {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path.string, isDirectory: &isDirectory), isDirectory.boolValue
    else {
      throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: path.string])
    }

    let root = URL(fileURLWithPath: path.string)
    guard
      let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles])
    else { return [] }

    var files = [String]()
    for case let url as URL in enumerator {
      if Self.skippedDirectories.contains(url.lastPathComponent) {
        enumerator.skipDescendants()
      } else if url.pathExtension == "swift" {
        files.append(url.path)
      }
    }
    return files
  }

  /// Files in a Swift package nested below each of `roots` that lists them, so the package's own
  /// `Package.swift` sits strictly between the root and the file. A root inside a package (for
  /// example `--package-path Packages/Core/Sources/Core`) keeps that package's files its own.
  static func nestedPackageFiles(_ files: Set<String>, roots: [String]) -> Set<String> {
    let roots = roots.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
    let packages =
      files
      .map { URL(fileURLWithPath: $0) }
      .filter { $0.lastPathComponent == "Package.swift" }
      .map { $0.deletingLastPathComponent().path }
    return files.filter { file in
      let containingRoots = roots.filter { file.hasPrefix($0 + "/") }
      return !containingRoots.isEmpty
        && containingRoots.allSatisfy { root in
          packages.contains { $0.hasPrefix(root + "/") && file.hasPrefix($0 + "/") }
        }
    }
  }

  func parseSwiftFiles(_ swiftFiles: Set<String>) throws -> [DependencyModule] {
    logger.log("📝 Starting to parse \(swiftFiles.count) Swift files")

    // Sorted so the generated file is identical between runs. Files are parsed in parallel, then
    // handled in this order.
    let files = swiftFiles.sorted()
    let results = ParseResults(count: files.count)
    DispatchQueue.concurrentPerform(iterations: files.count) { index in
      results[index] = Result { try Self.parse(files[index]) }
    }

    // Unsupported providers are collected from every file so they're all reported in one run.
    var diagnostics = [String]()
    var modules = [DependencyModule]()
    for (file, result) in zip(files, results.values) {
      switch try result.get() {
      case .skipped:
        logger.log("Skipped file without modules: \(file)")
      case .unsupportedProviders(let fileDiagnostics):
        diagnostics += fileDiagnostics
      case .modules(let fileModules):
        logger.log("Parsed file: \(file)")
        logger.log("  Found \(fileModules.count) modules in \(URL(fileURLWithPath: file).lastPathComponent)")
        fileModules.forEach { logger.log("    - \($0.name)") }
        modules += fileModules
      }
    }

    guard diagnostics.isEmpty else { throw ParserError.unsupportedProviders(diagnostics) }
    return modules
  }

  func generateDependenciesFile(
    modules: [DependencyModule],
    externalModules: [DependencyModule],
    registry: RegistryConfiguration
  ) throws -> String {
    logger.log("🔨 Generating \(registry.name) from \(modules.count) modules (\(externalModules.count) external)")

    logger.log("Resolving dependency graph...")
    let resolver = DependencyGraphResolver(data: modules + externalModules)
    let buildMap = try resolver.resolveAndValidate()
    logger.log("✅ Dependency graph resolved with \(buildMap.count) entries")
    resolver.captiveDependencyWarnings(in: modules).forEach(logger.warn)

    logger.log("Build order:")
    buildMap.enumerated().forEach { logger.log("  \($1)-> \($0 + 1)") }

    let presenter = DependencyFilePresenter(data: modules, dependenciesOrder: buildMap, registry: registry)
    var file = ""
    DependencyFile(presenter: presenter).file.write(to: &file)
    logger.log("✅ \(registry.name) generated")

    return file
  }

  enum ValidationError: LocalizedError {
    case git(String, String)

    var errorDescription: String? {
      switch self {
      case let .git(root, message):
        "Git error in \(root). \(message)"
      }
    }
  }
}

private extension SwiftFilesHandler {
  enum FileParse {
    case skipped
    case modules([DependencyModule])
    case unsupportedProviders([String])
  }

  static func parse(_ file: String) throws -> FileParse {
    let content = try String(contentsOf: URL(fileURLWithPath: file), encoding: .utf8)
    // A module conforms to one of the `...Scope` protocols, so a file without the word declares none.
    guard content.contains("Scope") else { return .skipped }

    let tree = Parser.parse(source: content)
    do {
      let modules = try DependencyModulesParser(viewMode: .all).parse(tree, fileName: file)
      return .modules(modules.sorted { $0.name < $1.name })
    } catch ParserError.unsupportedProviders(let diagnostics) {
      return .unsupportedProviders(diagnostics)
    }
  }

  /// Per-file results, written from `concurrentPerform`.
  final class ParseResults: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<FileParse, Error>?]

    init(count: Int) {
      results = Array(repeating: nil, count: count)
    }

    subscript(index: Int) -> Result<FileParse, Error>? {
      get { lock.withLock { results[index] } }
      set { lock.withLock { results[index] = newValue } }
    }

    /// Every result, once all iterations have finished.
    var values: [Result<FileParse, Error>] {
      lock.withLock { results.compactMap { $0 } }
    }
  }
}
