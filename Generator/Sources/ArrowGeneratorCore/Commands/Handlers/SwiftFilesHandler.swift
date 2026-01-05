import Foundation
import PathKit
import SwiftParser
import SwiftSyntax

protocol SwiftFilesHandlerProtocol {
  func getAllSwiftFiles(in swiftDirs: [String]) throws -> Set<String>
  func parseSwiftFiles(_ swiftFiles: Set<String>) throws -> [DependencyModule]
  func generateDependenciesFile(modules: [DependencyModule]) throws -> String
}

final class SwiftFilesHandler: SwiftFilesHandlerProtocol {
  let parser: Parser.Type
  let syntaxVisitor: DependencyModulesParser
  let logger: Logging

  init(
    parser: Parser.Type = Parser.self,
    syntaxVisitor: DependencyModulesParser = DependencyModulesParser(viewMode: .all),
    logger: Logging
  ) {
    self.parser = parser
    self.syntaxVisitor = syntaxVisitor
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
          return try swiftFilesRecursivelly(in: path)
        } catch {
          logger.log("⚠️  Failed to read directory: \(path.string) - \(error.localizedDescription)")
          return nil
        }
      }
      .flatMap { $0 }
      .asSet()

    logger.log("✅ Found \(swiftFiles.count) Swift files")
    swiftFiles.sorted().forEach { logger.log("  - \($0)") }

    return swiftFiles
  }

  func swiftFilesUsingGit(in repoPath: Path) throws -> [String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "git",
      "ls-files",
      "*.swift",
      "--cached",
      "--others",
      "--exclude-standard",
    ]

    process.currentDirectoryURL = URL(fileURLWithPath: repoPath.string)

    let pipe = Pipe()
    process.standardOutput = pipe

    let errorPipe = Pipe()
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
      let errorMessage = String(data: errorData, encoding: .utf8)
      throw ValidationError.git(repoPath.string, errorMessage ?? "")
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    return
      output
      .split(separator: "\n")
      .map(String.init)
      .map { "\(repoPath)/\($0)" }
  }

  func swiftFilesRecursivelly(in path: Path) throws -> [String] {
    try path.recursiveChildren()
      .filter { $0.extension == "swift" }
      .map { $0.string }
  }

  func parseSwiftFiles(_ swiftFiles: Set<String>) throws -> [DependencyModule] {
    logger.log("📝 Starting to parse \(swiftFiles.count) Swift files")

    return try swiftFiles.flatMap {
      logger.log("Parsing file: \($0)")

      let path = URL(fileURLWithPath: $0)
      let content = try String(contentsOf: path)
      let tree = Parser.parse(source: content)
      let syntaxVisitor = DependencyModulesParser(viewMode: .all)
      let fileModules = syntaxVisitor.parse(tree)

      logger.log("  Found \(fileModules.count) modules in \(path.lastPathComponent)")
      fileModules.forEach { logger.log("    - \($0.name)") }

      return fileModules
    }
  }

  func generateDependenciesFile(modules: [DependencyModule]) throws -> String {
    logger.log("🔨 Generating dependencies file from \(modules.count) modules")

    logger.log("Resolving dependency graph...")
    let buildMap = try DependencyGraphResolver(data: modules).resolveAndValidate()
    logger.log("✅ Dependency graph resolved with \(buildMap.count) entries")

    logger.log("Build order:")
    buildMap.enumerated().forEach { logger.log("  \($1)-> \($0 + 1)") }

    let presenter = DependencyFilePresenter(data: modules, dependenciesOrder: buildMap)
    var file = ""
    DependencyFile(presenter: presenter).file.write(to: &file)
    logger.log("✅ Dependency extension updated")

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
