import Foundation
import XcodeProj

final class XcodeProjHandler {
    let swiftHandler: SwiftFilesHandlerProtocol
    let xcodeProj: XcodeProjFile
    let generatedFileName: String

    init(
        swiftHandler: SwiftFilesHandlerProtocol,
        xcodeProj: XcodeProjFile,
        generatedFileName: String
    ) {
        self.swiftHandler = swiftHandler
        self.xcodeProj = xcodeProj
        self.generatedFileName = generatedFileName
    }

    func addDependenciesFileToXcodeProject(
        projRoot: String,
        packageSourcesPaths: [String]
    ) throws {
        let allPaths = packageSourcesPaths + [projRoot]
        let swiftFiles = try swiftHandler.getAllSwiftFiles(in: allPaths)
        let modules = try swiftHandler.parseSwiftFiles(swiftFiles)
        let file = try swiftHandler.generateDependenciesFile(modules: modules)
        try xcodeProj.createFile(name: generatedFileName, content: file)
    }
}
