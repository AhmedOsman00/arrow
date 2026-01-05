import XCTest

@testable import ArrowGeneratorCore

class DependencyRegistrationGeneratorTests: XCTestCase {
  func testPackageMode_WhenPackageSourcesPathMissing_ThrowsValidationError() {
    var generator = DependencyRegistrationGenerator()
    generator.verbose = false
    generator.isPackage = true
    generator.packageSourcesPaths = []
    XCTAssertThrowsError(try generator.run()) { error in
      XCTAssertTrue(error is DependencyRegistrationGenerator.ValidationError)
      XCTAssertEqual(error.localizedDescription, "Argument: --package-path is required.")
    }
  }

  func testXcodeMode_WhenProjRootMissing_ThrowsValidationError() {
    var generator = DependencyRegistrationGenerator()
    generator.verbose = false
    generator.isPackage = false
    generator.projRoot = nil

    XCTAssertThrowsError(try generator.run()) { error in
      XCTAssertTrue(error is DependencyRegistrationGenerator.ValidationError)
      XCTAssertEqual(error.localizedDescription, "Argument: --proj-root is required.")
    }
  }
}
