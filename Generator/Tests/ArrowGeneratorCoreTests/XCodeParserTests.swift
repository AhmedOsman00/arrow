import XCTest
import PathKit
@testable import ArrowGeneratorCore

final class XCodeParserTests: XCTestCase {

    // MARK: - Parse Tests

    func testParse_returnsSwiftFilesOnly() throws {
        // Arrange
        let mockProject = try MockXcodeProj(
            targetName: "MyApp",
            swiftFiles: ["ViewController.swift", "Model.swift", "Service.swift"],
            otherFiles: ["README.md", "Config.plist"]
        )

        let parser = try XcodeFileParser(
            project: mockProject,
            xcodeProjPath: Path("/project/MyApp.xcodeproj"),
            target: "MyApp"
        )

        // Act
        let result = try parser.parse()

        // Assert
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.contains("/project/ViewController.swift"))
        XCTAssertTrue(result.contains("/project/Model.swift"))
        XCTAssertTrue(result.contains("/project/Service.swift"))
        XCTAssertFalse(result.contains("/project/README.md"))
        XCTAssertFalse(result.contains("/project/Config.plist"))
    }

    func testParse_returnsEmptyArray_whenNoSwiftFiles() throws {
        // Arrange
        let mockProject = try MockXcodeProj(
            targetName: "MyApp",
            swiftFiles: [],
            otherFiles: ["README.md", "Config.plist"]
        )

        let parser = try XcodeFileParser(
            project: mockProject,
            xcodeProjPath: Path("/project/MyApp.xcodeproj"),
            target: "MyApp"
        )

        // Act
        let result = try parser.parse()

        // Assert
        XCTAssertEqual(result.count, 0)
    }

    func testParse_returnsEmptyArray_whenTargetNotFound() throws {
        // Arrange
        let mockProject = try MockXcodeProj(
            targetName: "DifferentTarget",
            swiftFiles: ["ViewController.swift"],
            otherFiles: []
        )

        let parser = try XcodeFileParser(
            project: mockProject,
            xcodeProjPath: Path("/project/MyApp.xcodeproj"),
            target: "MyApp"
        )

        // Act
        let result = try parser.parse()

        // Assert
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - isFileAlreadyAdded Tests

    func testIsFileAlreadyAdded_returnsTrue_whenFileExists() throws {
        // Arrange
        let mockProject = try MockXcodeProj(
            targetName: "MyApp",
            swiftFiles: ["ViewController.swift", "Model.swift"],
            otherFiles: []
        )

        let parser = try XcodeFileParser(
            project: mockProject,
            xcodeProjPath: Path("/project/MyApp.xcodeproj"),
            target: "MyApp"
        )

        // Act
        let result = try parser.isFileAlreadyAdded(path: "ViewController.swift")

        // Assert
        XCTAssertTrue(result)
    }

    func testIsFileAlreadyAdded_returnsFalse_whenFileDoesNotExist() throws {
        // Arrange
        let mockProject = try MockXcodeProj(
            targetName: "MyApp",
            swiftFiles: ["ViewController.swift"],
            otherFiles: []
        )

        let parser = try XcodeFileParser(
            project: mockProject,
            xcodeProjPath: Path("/project/MyApp.xcodeproj"),
            target: "MyApp"
        )

        // Act
        let result = try parser.isFileAlreadyAdded(path: "NewFile.swift")

        // Assert
        XCTAssertFalse(result)
    }

    func testIsFileAlreadyAdded_returnsFalse_whenTargetNotFound() throws {
        // Arrange
        let mockProject = try MockXcodeProj(
            targetName: "DifferentTarget",
            swiftFiles: [],
            otherFiles: []
        )

        let parser = try XcodeFileParser(
            project: mockProject,
            xcodeProjPath: Path("/project/MyApp.xcodeproj"),
            target: "MyApp"
        )

        // Act
        let result = try parser.isFileAlreadyAdded(path: "ViewController.swift")

        // Assert
        XCTAssertFalse(result)
    }

    // MARK: - addFile Tests

    func testAddFile_succeeds_whenTargetExists() throws {
        // Arrange
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("NewFile.swift")
        try "// Test file".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let mockProject = try MockXcodeProj(
            targetName: "MyApp",
            swiftFiles: [],
            otherFiles: [],
            hasMainGroup: true
        )

        let parser = try XcodeFileParser(
            project: mockProject,
            xcodeProjPath: Path("/project/MyApp.xcodeproj"),
            target: "MyApp"
        )

        // Act & Assert
        XCTAssertNoThrow(try parser.addFile(path: tempFile.path))
        XCTAssertTrue(mockProject.writeWasCalled)
    }

    func testAddFile_throwsError_whenTargetNotFound() throws {
        // Arrange
        let mockProject = try MockXcodeProj(
            targetName: "DifferentTarget",
            swiftFiles: [],
            otherFiles: []
        )

        let parser = try XcodeFileParser(
            project: mockProject,
            xcodeProjPath: Path("/project/MyApp.xcodeproj"),
            target: "MyApp"
        )

        // Act & Assert
        XCTAssertThrowsError(try parser.addFile(path: "NewFile.swift")) { error in
            XCTAssertTrue(error is XcodeFileParser.XcodeParserError)
            if let parserError = error as? XcodeFileParser.XcodeParserError {
                XCTAssertEqual(parserError, .targetNotFound)
                XCTAssertEqual(parserError.localizedDescription, "Target not found")
            }
        }
        XCTAssertFalse(mockProject.writeWasCalled)
    }

    func testAddFile_throwsError_whenMainGroupNotFound() throws {
        // Arrange
        let mockProject = try MockXcodeProj(
            targetName: "MyApp",
            swiftFiles: [],
            otherFiles: [],
            hasMainGroup: false
        )

        let parser = try XcodeFileParser(
            project: mockProject,
            xcodeProjPath: Path("/project/MyApp.xcodeproj"),
            target: "MyApp"
        )

        // Act & Assert
        XCTAssertThrowsError(try parser.addFile(path: "NewFile.swift")) { error in
            XCTAssertTrue(error is XcodeFileParser.XcodeParserError)
            if let parserError = error as? XcodeFileParser.XcodeParserError {
                XCTAssertEqual(parserError, .malformedXcodeProjFile)
                XCTAssertEqual(parserError.localizedDescription, "Malformed XcodeProj file")
            }
        }
    }
}
