import XCTest

import class Foundation.Bundle

final class ArrowTests: XCTestCase {
  func testCLI_withoutArguments_showsHelpOverview() throws {
    // Verifies that running the Arrow CLI without arguments displays the help overview

    // Some of the APIs that we use below are available in macOS 10.13 and above.
    guard #available(macOS 10.13, *) else {
      return
    }

    // Mac Catalyst won't have `Process`, but it is supported for executables.
    #if !targetEnvironment(macCatalyst)

      let fooBinary = productsDirectory.appendingPathComponent("Arrow")

      let process = Process()
      process.executableURL = fooBinary

      let pipe = Pipe()
      process.standardOutput = pipe

      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8)

      // Verify the tool shows help overview when run without arguments
      XCTAssertNotNil(output)
      XCTAssertTrue(output?.contains("OVERVIEW: A Swift command-line tool") ?? false)
      XCTAssertTrue(output?.contains("USAGE: arrow <subcommand>") ?? false)
      XCTAssertTrue(output?.contains("generate") ?? false)
    #endif
  }

  /// Returns path to the built products directory.
  var productsDirectory: URL {
    #if os(macOS)
      for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
        return bundle.bundleURL.deletingLastPathComponent()
      }
      fatalError("couldn't find the products directory")
    #else
      return Bundle.main.bundleURL
    #endif
  }
}
