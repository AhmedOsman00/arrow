import XCTest

@testable import ArrowGeneratorCore

final class BuildSettingsTests: XCTestCase {
  func testReadsArrowSettings() {
    let settings = BuildSettings(environment: [
      "ARROW_REGISTRY_NAME": "AppDependencies",
      "ARROW_EXT_PATH": "/app/Generated/dependencies.generated.swift",
      "ARROW_PACKAGE_PATHS": "/app/Packages/Core/Sources/Core",
      "ARROW_EXTERNAL_PATHS": "/app/Packages/Analytics/Sources/Analytics /app/Packages/Network/Sources/Network",
    ])

    XCTAssertEqual(settings.registryName, "AppDependencies")
    XCTAssertEqual(settings.extPath, "/app/Generated/dependencies.generated.swift")
    XCTAssertEqual(settings.packagePaths, ["/app/Packages/Core/Sources/Core"])
    XCTAssertEqual(
      settings.externalPaths,
      ["/app/Packages/Analytics/Sources/Analytics", "/app/Packages/Network/Sources/Network"])
  }

  func testMissingOrEmptySettings_AreIgnored() {
    let settings = BuildSettings(environment: ["ARROW_REGISTRY_NAME": "", "ARROW_EXTERNAL_PATHS": "  "])

    XCTAssertNil(settings.registryName)
    XCTAssertNil(settings.extPath)
    XCTAssertEqual(settings.packagePaths, [])
    XCTAssertEqual(settings.externalPaths, [])
  }

  func testList_HandlesQuotesAndEscapedSpaces() {
    XCTAssertEqual(
      BuildSettings.list(#"  "/My App/Sources" /plain '/single quoted' /escaped\ space "" "#),
      ["/My App/Sources", "/plain", "/single quoted", "/escaped space", ""])
  }
}
