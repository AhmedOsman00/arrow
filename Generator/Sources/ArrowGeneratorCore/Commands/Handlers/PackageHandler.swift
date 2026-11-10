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
    if try file.writeIfChanged(toFile: outputPath.string) {
      logger.log("✅ Wrote \(outputPath.string)")
    } else {
      logger.log("✅ \(outputPath.string) is up to date")
    }
  }
}
