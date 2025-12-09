import XCTest
@testable import ArrowGeneratorCore

class DependencyRegistrationGeneratorTests: XCTestCase {
    
    func testPackageMode_WhenPackageSourcesPathMissing_ThrowsValidationError() {
        var generator = DependencyRegistrationGenerator()
        generator.isPackage = true
        generator.packageSourcesPaths = []
        XCTAssertThrowsError(try generator.run()) { error in
            XCTAssertTrue(error is DependencyRegistrationGenerator.ValidationError)
            XCTAssertEqual(error.localizedDescription, "Argument: --package-sources-path is required.")
        }
    }

    func testXcodeMode_WhenTargetNameMissing_ThrowsValidationError() {
        var generator = DependencyRegistrationGenerator()
        generator.isPackage = false
        generator.targetName = nil

        XCTAssertThrowsError(try generator.run()) { error in
            XCTAssertTrue(error is DependencyRegistrationGenerator.ValidationError)
            XCTAssertEqual(error.localizedDescription, "Argument: --target-name is required.")
        }
    }

    func testXcodeMode_WhenXcodeProjPathMissing_ThrowsValidationError() {
        var generator = DependencyRegistrationGenerator()
        generator.isPackage = false
        generator.targetName = "Main"
        generator.xcodeProjPath = nil

        XCTAssertThrowsError(try generator.run()) { error in
            XCTAssertTrue(error is DependencyRegistrationGenerator.ValidationError)
            XCTAssertEqual(error.localizedDescription, "Argument: --xcode-proj-path is required.")
        }
    }
}
