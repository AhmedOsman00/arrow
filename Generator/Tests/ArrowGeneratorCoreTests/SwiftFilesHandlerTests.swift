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

  func testGetAllSwiftFiles_WithoutGit_SkipsBuildAndHiddenDirectories() throws {
    let tempDir = createTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    for directory in [".build", "DerivedData", ".hidden"] {
      let url = tempDir.appendingPathComponent(directory)
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
      try createFile(at: url, name: "Skipped.swift", content: "// skipped")
    }
    try createFile(at: tempDir, name: "Kept.swift", content: "// kept")

    let result = try sut.getAllSwiftFiles(in: [tempDir.path])

    XCTAssertEqual(result.count, 1)
    XCTAssertTrue(result.contains { $0.hasSuffix("Kept.swift") })
  }

  func testGetAllSwiftFiles_InGitRepo_RespectsIgnoreAndSkipsDeletedFiles() throws {
    let tempDir = createTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try git(["init", "-q"], in: tempDir)
    try createFile(at: tempDir, name: ".gitignore", content: "Ignored.swift\n")
    try createFile(at: tempDir, name: "A.swift", content: "// a")
    try createFile(at: tempDir, name: "Z.swift", content: "// z")
    try createFile(at: tempDir, name: "Ignored.swift", content: "// ignored")
    try git(["add", "A.swift", "Z.swift"], in: tempDir)
    // Tracked but deleted, and listed last by git.
    try FileManager.default.removeItem(at: tempDir.appendingPathComponent("Z.swift"))

    let result = try sut.getAllSwiftFiles(in: [tempDir.path])

    // Ignored.swift being absent shows git was used rather than the directory walk.
    XCTAssertEqual(result.map { URL(fileURLWithPath: $0).lastPathComponent }, ["A.swift"])
  }

  func testGetAllSwiftFiles_WithOverlappingDirectories_ReturnsEachFileOnce() throws {
    let tempDir = createTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let subDir = tempDir.appendingPathComponent("Sources")
    try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
    try createFile(at: subDir, name: "Module.swift", content: "// module")

    let result = try sut.getAllSwiftFiles(in: [tempDir.path + "/.", subDir.path])

    XCTAssertEqual(result.count, 1)
  }

  func testGenerateDependenciesFile_ExternalPathSatisfiesValidationButIsNotEmitted() throws {
    let tempDir = createTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // The external package lives inside the app root, as in the Example project.
    let externalDir = tempDir.appendingPathComponent("Packages/Analytics")
    try FileManager.default.createDirectory(at: externalDir, withIntermediateDirectories: true)
    try createFile(
      at: externalDir, name: "AnalyticsModule.swift",
      content: """
        import Arrow
        public struct AnalyticsModule: SingletonScope {
          public init() {}
          public func provideAnalytics() -> Analytics { AnalyticsImpl() }
        }
        """)
    try createFile(
      at: tempDir, name: "HomeModule.swift",
      content: """
        import Arrow
        import Analytics
        final class HomeModule: TransientScope {
          func provideViewModel(analytics: Analytics) -> HomeViewModel { HomeViewModel(analytics: analytics) }
        }
        """)

    let file = try sut.generateDependenciesFile(
      paths: [tempDir.path],
      externalPaths: [externalDir.path],
      registry: .fixture)

    XCTAssertTrue(file.contains("enum AppDependencies: DependencyRegistry"))
    XCTAssertTrue(file.contains("homeModule.provideViewModel("))
    XCTAssertTrue(file.contains("analytics: resolver.resolve(Analytics.self)"))
    XCTAssertFalse(file.contains("AnalyticsModule"), "External providers must not be emitted")
  }

  func testGenerateDependenciesFile_WithoutExternalPath_ReportsMissingDependency() throws {
    let tempDir = createTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try createFile(
      at: tempDir, name: "HomeModule.swift",
      content: """
        final class HomeModule: TransientScope {
          func provideViewModel(analytics: Analytics) -> HomeViewModel { HomeViewModel(analytics: analytics) }
        }
        """)

    XCTAssertThrowsError(
      try sut.generateDependenciesFile(paths: [tempDir.path], externalPaths: [], registry: .fixture))
  }

  func testGenerateDependenciesFile_KeepsIfConfigAndGroupsExistentials() throws {
    let tempDir = createTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try createFile(
      at: tempDir, name: "LoggingModule.swift",
      content: """
        import Arrow
        #if canImport(UIKit)
        import UIKit
        #endif

        final class LoggingModule: SingletonScope {
          #if DEBUG
          var logger: any Logger { ConsoleLogger() }
          #else
          var logger: any Logger { NoopLogger() }
          #endif

          func tracker(logger: any Logger) -> Tracker { Tracker(logger: logger) }
        }
        """)

    let file = try sut.generateDependenciesFile(paths: [tempDir.path], externalPaths: [], registry: .fixture)

    let expected = """
      // Generated by arrow. Do not edit.

      import Arrow
      #if canImport(UIKit)
      import UIKit
      #endif

      enum AppDependencies: DependencyRegistry {
        static func register(in container: Container) {
          let loggingModule = LoggingModule()

          #if !DEBUG
          container.register((any Logger).self, objectScope: .singleton) { resolver in
            loggingModule.logger
          }
          #endif

          #if DEBUG
          container.register((any Logger).self, objectScope: .singleton) { resolver in
            loggingModule.logger
          }
          #endif

          container.register(Tracker.self, objectScope: .singleton) { resolver in
            loggingModule.tracker(
              logger: resolver.resolve((any Logger).self)
            )
          }
        }
      }
      """
    XCTAssertEqual(file, expected)
  }

  func testGenerateDependenciesFile_OptionalParametersAndMainActorRegistry() throws {
    let tempDir = createTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try createFile(
      at: tempDir, name: "Modules.swift",
      content: """
        import Arrow

        final class CoreModule: TransientScope {
          var formatter: Formatter { Formatter() }
        }

        @MainActor
        final class ScreenModule: SingletonScope {
          nonisolated init() {}

          func viewModel(cache: Cache?, formatter: Formatter?) -> ViewModel {
            ViewModel(cache: cache, formatter: formatter)
          }
        }
        """)
    // No `Scope` in the text, so the file is skipped without being parsed.
    try createFile(at: tempDir, name: "Other.swift", content: "import Foundation")

    let logger = LoggingMock()
    let file = try SwiftFilesHandler(logger: logger)
      .generateDependenciesFile(paths: [tempDir.path], externalPaths: [], registry: .fixture)

    let expected = """
      // Generated by arrow. Do not edit.

      import Arrow
      import Foundation

      @MainActor
      enum AppDependencies: @preconcurrency DependencyRegistry {
        static func register(in container: Container) {
          let coreModule = CoreModule()
          let screenModule = ScreenModule()

          container.register(Formatter.self, objectScope: .transient) { resolver in
            coreModule.formatter
          }

          container.register(ViewModel.self, objectScope: .singleton) { resolver in
            precondition(Thread.isMainThread, "`ViewModel` is created on the main actor, so resolve it on the main thread.")
            return screenModule.viewModel(
              cache: resolver.tryResolve(Cache.self),
              formatter: resolver.tryResolve(Formatter.self)
            )
          }
        }
      }
      """
    XCTAssertEqual(file, expected)
    XCTAssertEqual(
      logger.warnings,
      [
        "`ScreenModule.viewModel` is a singleton but depends on transient `Formatter`, "
          + "so it keeps one instance of it forever."
      ])
  }

  func testGenerateDependenciesFile_ChecksMainThreadOnlyForMainActorProviders() throws {
    let tempDir = createTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try createFile(
      at: tempDir, name: "Module.swift",
      content: """
        final class AppModule: SingletonScope {
          var clock: Clock { Clock() }

          @MainActor
          var screen: Screen { Screen() }
        }
        """)

    let file = try sut.generateDependenciesFile(paths: [tempDir.path], externalPaths: [], registry: .fixture)

    XCTAssertTrue(file.contains("import Foundation"))
    XCTAssertTrue(file.contains("@MainActor\nenum AppDependencies: @preconcurrency DependencyRegistry"))
    XCTAssertEqual(file.components(separatedBy: "precondition(Thread.isMainThread").count - 1, 1)
    XCTAssertTrue(
      file.contains(
        "  precondition(Thread.isMainThread, \"`Screen` is created on the main actor, so resolve it on the main thread.\")\n"
          + "      return appModule.screen\n"))
    XCTAssertTrue(file.contains("{ resolver in\n      appModule.clock\n    }"))
  }

  func testGenerateDependenciesFile_TreatsNestedPackagesAsExternal() throws {
    let tempDir = createTempDirectory()
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let package = tempDir.appendingPathComponent("Packages/Analytics")
    let sources = package.appendingPathComponent("Sources/Analytics")
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)

    try createFile(at: package, name: "Package.swift", content: "import PackageDescription")
    try createFile(
      at: sources, name: "AnalyticsModule.swift",
      content: "public final class AnalyticsModule: SingletonScope { public var analytics: Analytics { Analytics() } }")
    try createFile(
      at: tempDir, name: "AppModule.swift",
      content: "final class AppModule: TransientScope { func screen(analytics: Analytics) -> Screen { Screen() } }")

    let file = try sut.generateDependenciesFile(paths: [tempDir.path], externalPaths: [], registry: .fixture)

    XCTAssertTrue(file.contains("analytics: resolver.resolve(Analytics.self)"))
    XCTAssertFalse(file.contains("AnalyticsModule"))
  }

  func testNestedPackageFiles_KeepsPackagesTheRootIsIn() {
    let files: Set<String> = [
      "/App/AppModule.swift",
      "/App/Package.swift",
      "/App/Packages/Core/Package.swift",
      "/App/Packages/Core/Sources/Core/CoreModule.swift",
      "/App/Packages/Core/Tests/CoreTests.swift",
    ]

    XCTAssertEqual(
      SwiftFilesHandler.nestedPackageFiles(files, roots: ["/App"]),
      [
        "/App/Packages/Core/Package.swift",
        "/App/Packages/Core/Sources/Core/CoreModule.swift",
        "/App/Packages/Core/Tests/CoreTests.swift",
      ])
    XCTAssertEqual(
      SwiftFilesHandler.nestedPackageFiles(files, roots: ["/App", "/App/Packages/Core/Sources/Core"]),
      ["/App/Packages/Core/Package.swift", "/App/Packages/Core/Tests/CoreTests.swift"])
    XCTAssertEqual(SwiftFilesHandler.nestedPackageFiles(files, roots: ["/App/Packages/Core"]), [])
  }

  // MARK: - Helper Methods

  private func git(_ arguments: [String], in directory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git"] + arguments
    process.currentDirectoryURL = directory
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0, "git \(arguments.joined(separator: " ")) failed")
  }

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
  private(set) var warnings = [String]()

  func log(_ message: String) {}

  func warn(_ message: String) {
    warnings.append(message)
  }
}

final class WriteIfChangedTests: XCTestCase {
  func testWriteIfChanged_skipsIdenticalContent() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    defer { try? FileManager.default.removeItem(atPath: path) }

    XCTAssertTrue(try "first".writeIfChanged(toFile: path))
    XCTAssertFalse(try "first".writeIfChanged(toFile: path))
    XCTAssertTrue(try "second".writeIfChanged(toFile: path))
    XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "second")
  }
}
