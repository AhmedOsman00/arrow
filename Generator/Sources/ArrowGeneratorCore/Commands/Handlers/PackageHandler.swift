import Foundation
import PathKit

final class PackageHandler {
    let swiftHandler: SwiftFilesHandlerProtocol
    let generatedFileName: String

    init(
        swiftHandler: SwiftFilesHandlerProtocol,
        generatedFileName: String
    ) {
        self.swiftHandler = swiftHandler
        self.generatedFileName = generatedFileName
    }

    func addDependenciesFileToSwiftPackage(packageSourcesPath: String) throws {
        let swiftFiles = try swiftHandler.getAllSwiftFiles(in: [packageSourcesPath])
        let modules = try swiftHandler.parseSwiftFiles(swiftFiles)
        let file = try swiftHandler.generateDependenciesFile(modules: modules)
        let outputPath = Path(packageSourcesPath) + Path(generatedFileName)
        try file.write(toFile: outputPath.string, atomically: true, encoding: .utf8)
    }
}
