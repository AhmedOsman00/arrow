import Foundation
import PathKit
import XcodeProj

/// Parses Xcode project files to extract Swift source file paths and manage project integration.
///
/// This class uses the XcodeProj library to:
/// - Extract all Swift files from a specific target
/// - Check if files are already included in the project
/// - Add new files to the project and build phases
///
/// Example usage:
/// ```swift
/// let project = try XcodeProj(path: Path("/path/to/App.xcodeproj"))
/// let parser = try XcodeFileParser(
///     project: project,
///     xcodeProjPath: Path("/path/to/App.xcodeproj"),
///     target: "MyApp"
/// )
/// let swiftFiles = try parser.parse()
/// ```
final class XcodeFileParser {
  /// Path to the .xcodeproj file
  private let xcodeProjPath: Path

  /// Name of the target to analyze
  private let target: String

  /// The Xcode project instance
  private let project: XcodeFileParsing

  /// Root directory of the project (parent of .xcodeproj)
  private var sourceRoot: Path {
    xcodeProjPath.parent()
  }

  /// The project's PBXProj object
  private var pbxproj: PBXProj {
    project.pbxproj
  }

  /// The target object matching the specified target name
  private var mainTarget: PBXTarget? {
    pbxproj.nativeTargets.first { $0.name == target }
  }

  /// Initializes the parser with an Xcode project
  ///
  /// - Parameters:
  ///   - project: The XcodeProj instance
  ///   - xcodeProjPath: Path to the .xcodeproj file
  ///   - target: Name of the target to analyze
  /// - Throws: If the project cannot be loaded
  init(
    project: XcodeFileParsing,
    xcodeProjPath: Path,
    target: String
  ) throws {
    self.xcodeProjPath = xcodeProjPath
    self.target = target
    self.project = project
  }

  /// Extracts all Swift file paths from the target
  ///
  /// - Returns: Array of absolute paths to Swift files in the target
  /// - Throws: If the target cannot be accessed or files cannot be enumerated
  func parse() throws -> [String] {
    return try mainTarget?
      .sourceFiles()
      .compactMap { try? $0.fullPath(sourceRoot: sourceRoot.string) }
      .filter { $0.hasSuffix(".swift") } ?? []
  }

  /// Checks if a file is already included in the target
  ///
  /// - Parameter path: The file path to check
  /// - Returns: `true` if the file is already in the target, `false` otherwise
  /// - Throws: If the target cannot be accessed
  func isFileAlreadyAdded(path: String) throws -> Bool {
    try mainTarget?.sourceFiles().contains { $0.path == path } ?? false
  }

  /// Adds a file to the project and target's sources build phase
  ///
  /// - Parameter path: Absolute path to the file to add
  /// - Throws: `XcodeParserError.targetNotFound` if target doesn't exist,
  ///           `XcodeParserError.malformedXcodeProjFile` if project structure is invalid,
  ///           or other errors if file operations fail
  func addFile(path: String) throws {
    guard let mainTarget else {
      throw XcodeParserError.targetNotFound
    }

    guard let main = pbxproj.rootObject?.mainGroup else {
      throw XcodeParserError.malformedXcodeProjFile
    }

    let fileRef = try main.addFile(at: Path(path), sourceRoot: sourceRoot)
    _ = try mainTarget.sourcesBuildPhase()?.add(file: fileRef)
    try project.write(path: xcodeProjPath, override: true)
  }

  /// Errors that can occur during Xcode project parsing
  enum XcodeParserError: LocalizedError {
    /// The specified target was not found in the project
    case targetNotFound

    /// The Xcode project file has an invalid or unexpected structure
    case malformedXcodeProjFile

    var localizedDescription: String {
      switch self {
      case .targetNotFound:
        "Target not found"
      case .malformedXcodeProjFile:
        "Malformed XcodeProj file"
      }
    }
  }
}
