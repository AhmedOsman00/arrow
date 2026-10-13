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
  func generateDependenciesFile(
    paths: [String],
    externalPaths: [String],
    registry: RegistryConfiguration
  ) throws -> String {
    let externalFiles = try getAllSwiftFiles(in: externalPaths)
    let ownFiles = try getAllSwiftFiles(in: paths).subtracting(externalFiles)
    return try generateDependenciesFile(
      modules: parseSwiftFiles(ownFiles),
      externalModules: parseSwiftFiles(externalFiles),
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

  func parseSwiftFiles(_ swiftFiles: Set<String>) throws -> [DependencyModule] {
    logger.log("📝 Starting to parse \(swiftFiles.count) Swift files")

    // Sorted so the generated file is identical between runs.
    return try swiftFiles.sorted().flatMap {
      logger.log("Parsing file: \($0)")

      let path = URL(fileURLWithPath: $0)
      let content = try String(contentsOf: path, encoding: .utf8)
      let tree = Parser.parse(source: content)
      let syntaxVisitor = DependencyModulesParser(viewMode: .all)
      let fileModules = syntaxVisitor.parse(tree).sorted { $0.name < $1.name }

      logger.log("  Found \(fileModules.count) modules in \(path.lastPathComponent)")
      fileModules.forEach { logger.log("    - \($0.name)") }

      return fileModules
    }
  }

  func generateDependenciesFile(
    modules: [DependencyModule],
    externalModules: [DependencyModule],
    registry: RegistryConfiguration
  ) throws -> String {
    logger.log("🔨 Generating \(registry.name) from \(modules.count) modules (\(externalModules.count) external)")

    logger.log("Resolving dependency graph...")
    let buildMap = try DependencyGraphResolver(data: modules + externalModules).resolveAndValidate()
    logger.log("✅ Dependency graph resolved with \(buildMap.count) entries")

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
