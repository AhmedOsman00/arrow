import Foundation
import PathKit

final class PackageHandler {
  let swiftHandler: SwiftFilesHandlerProtocol
  let generatedFileName: String
  let logger: Logging

  init(
    swiftHandler: SwiftFilesHandlerProtocol,
    generatedFileName: String,
    logger: Logging
  ) {
    self.swiftHandler = swiftHandler
    self.generatedFileName = generatedFileName
    self.logger = logger
  }

  /// Scans every path and writes the generated file into the first one.
  func addDependenciesFileToSwiftPackage(packageSourcesPaths: [String]) throws {
    guard let outputDirectory = packageSourcesPaths.first else { return }
    let swiftFiles = try swiftHandler.getAllSwiftFiles(in: packageSourcesPaths)
    let modules = try swiftHandler.parseSwiftFiles(swiftFiles)
    let file = try swiftHandler.generateDependenciesFile(modules: modules)
    let outputPath = Path(outputDirectory) + Path(generatedFileName)
    try file.write(toFile: outputPath.string, atomically: true, encoding: .utf8)
  }
}
