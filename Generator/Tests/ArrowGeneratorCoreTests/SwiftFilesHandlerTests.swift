import XCTest

@testable import ArrowGeneratorCore

final class SwiftFilesHandlerTests: XCTestCase {
    var sut: SwiftFilesHandler!

    override func setUp() {
        super.setUp()
        sut = SwiftFilesHandler(logger: LoggingMock())
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testGetAllSwiftFiles_WithEmptyDirectories_ReturnsEmptySet() throws {
        let result = try sut.getAllSwiftFiles(in: [])

        XCTAssertTrue(result.isEmpty)
    }

    func testGetAllSwiftFiles_WithValidDirectory_ReturnsSwiftFiles() throws {
        let tempDir = createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create test Swift files
        try createFile(at: tempDir, name: "File1.swift", content: "import Foundation")
        try createFile(at: tempDir, name: "File2.swift", content: "class Test {}")
        try createFile(at: tempDir, name: "NotSwift.txt", content: "text")

        let result = try sut.getAllSwiftFiles(in: [tempDir.path])

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.hasSuffix("File1.swift") })
        XCTAssertTrue(result.contains { $0.hasSuffix("File2.swift") })
        XCTAssertFalse(result.contains { $0.hasSuffix("NotSwift.txt") })
    }

    func testGetAllSwiftFiles_WithNestedDirectories_ReturnsAllSwiftFiles() throws {
        let tempDir = createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let subDir = tempDir.appendingPathComponent("SubDir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        try createFile(at: tempDir, name: "Root.swift", content: "// root")
        try createFile(at: subDir, name: "Nested.swift", content: "// nested")

        let result = try sut.getAllSwiftFiles(in: [tempDir.path])

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.hasSuffix("Root.swift") })
        XCTAssertTrue(result.contains { $0.hasSuffix("Nested.swift") })
    }

    func testGetAllSwiftFiles_WithMultipleDirectories_CombinesResults() throws {
        let tempDir1 = createTempDirectory()
        let tempDir2 = createTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: tempDir1)
            try? FileManager.default.removeItem(at: tempDir2)
        }

        try createFile(at: tempDir1, name: "File1.swift", content: "// 1")
        try createFile(at: tempDir2, name: "File2.swift", content: "// 2")

        let result = try sut.getAllSwiftFiles(in: [tempDir1.path, tempDir2.path])

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.hasSuffix("File1.swift") })
        XCTAssertTrue(result.contains { $0.hasSuffix("File2.swift") })
    }

    func testGetAllSwiftFiles_WithNonExistentDirectory_HandlesGracefully() throws {
        let result = try sut.getAllSwiftFiles(in: ["/non/existent/path"])

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Helper Methods

    private func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    @discardableResult
    private func createFile(at directory: URL, name: String, content: String) throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}

final class LoggingMock: Logging {
    func log(_ message: String) {}
}
