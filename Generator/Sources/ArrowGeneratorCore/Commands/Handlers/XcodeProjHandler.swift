import Foundation
import PathKit

final class XcodeProjHandler {
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

  func addDependenciesFileToXcodeProject(
    projRoot: String,
    packageSourcesPaths: [String],
    externalPaths: [String],
    depsExtPath: String,
    registry: RegistryConfiguration
  ) throws {
    let file = try swiftHandler.generateDependenciesFile(
      paths: packageSourcesPaths + [projRoot],
      externalPaths: externalPaths,
      registry: registry)

    guard Path(depsExtPath).exists else {
      throw ValidationError.fileNotFound
    }

    try file.write(toFile: depsExtPath, atomically: true, encoding: .utf8)
  }

  enum ValidationError: LocalizedError {
    case fileNotFound

    var errorDescription: String? {
      switch self {
      case .fileNotFound:
        // swiftlint:disable:next line_length
        "dependencies.generated.swift file was not found. Please create it manually and add it to your project. or use --ext-path to specify the path to it."
      }
    }
  }
}
