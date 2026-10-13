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
  func addDependenciesFileToSwiftPackage(
    packageSourcesPaths: [String],
    externalPaths: [String],
    registry: RegistryConfiguration
  ) throws {
    guard let outputDirectory = packageSourcesPaths.first else { return }
    let file = try swiftHandler.generateDependenciesFile(
      paths: packageSourcesPaths,
      externalPaths: externalPaths,
      registry: registry)
    let outputPath = Path(outputDirectory) + Path(generatedFileName)
    try file.write(toFile: outputPath.string, atomically: true, encoding: .utf8)
  }
}
