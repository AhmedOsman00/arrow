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
            .compactMap { path -> [Path]? in
                do {
                    return try path.recursiveChildren()
                } catch {
                    logger.log("⚠️  Failed to read directory: \(path.string) - \(error.localizedDescription)")
                    return nil
                }
            }
            .flatMap { $0 }
            .filter { $0.extension == "swift" }
            .map { $0.string }
            .asSet()

        logger.log("✅ Found \(swiftFiles.count) Swift files")
        swiftFiles.sorted().forEach { logger.log("  - \($0)") }

        return swiftFiles
    }

    func parseSwiftFiles(_ swiftFiles: Set<String>) throws -> [DependencyModule] {
        logger.log("📝 Starting to parse \(swiftFiles.count) Swift files")

        let modules = try swiftFiles.flatMap { filePath -> Set<DependencyModule> in
            logger.log("Parsing file: \(filePath)")

            let path = URL(fileURLWithPath: filePath)
            let content = try String(contentsOf: path)
            let tree = parser.parse(source: content)
            let fileModules = syntaxVisitor.parse(tree)

            logger.log("  Found \(fileModules.count) modules in \(path.lastPathComponent)")
            fileModules.forEach { logger.log("    - \($0.name)") }

            return fileModules
        }

        return modules
    }

    func generateDependenciesFile(modules: [DependencyModule]) throws -> String {
        logger.log("🔨 Generating dependencies file from \(modules.count) modules")

        logger.log("Resolving dependency graph...")
        let buildMap = try DependencyGraphResolver(data: modules).resolveAndValidate()
        logger.log("✅ Dependency graph resolved with \(buildMap.count) entries")

        logger.log("Build order:")
        buildMap.enumerated().forEach { logger.log("  \($1)-> \($0 + 1)") }

        logger.log("Creating dependency file presentation...")
        let presenter = DependencyFilePresenter(data: modules, dependenciesOrder: buildMap)
        var file = ""
        DependencyFile(presenter: presenter).file.write(to: &file)

        return file
    }
}
