import PathKit
import XCTest
import XcodeProj

@testable import ArrowGeneratorCore

final class XcodeProjFileTests: XCTestCase {
  var projectPath: Path!

  override func setUp() {
    super.setUp()
    let tempDir = FileManager.default.temporaryDirectory
    let createdPath = tempDir.appendingPathComponent("MockProject/MockProject.xcodeproj")
    projectPath = Path(createdPath.path())
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: projectPath.parent().url)
    super.tearDown()
  }

  func testAddFile_succeeds_whenTargetExists() throws {
    // Arrange
    let fileName = "Dependencies.swift"
    let mockProject = try createTemporaryProject()

    let xcodeProjFile = try XcodeProjFile(
      project: mockProject,
      xcodeProjPath: projectPath,
      target: "Example"
    )

    // Act & Assert
    XCTAssertNoThrow(try xcodeProjFile.createFile(name: fileName, content: "// Test file"))
    let result = try isFileExist(proj: mockProject, target: "Example", name: fileName)
    XCTAssertTrue(result)
  }

  func testAddFile_throwsError_whenTargetNotFound() throws {
    // Arrange
    let fileName = "Dependencies.swift"
    let mockProject = try createTemporaryProject()

    let xcodeProjFile = try XcodeProjFile(
      project: mockProject,
      xcodeProjPath: projectPath,
      target: "NoTarget"
    )

    // Act & Assert
    XCTAssertThrowsError(try xcodeProjFile.createFile(name: fileName, content: "")) { error in
      XCTAssertTrue(error is XcodeProjFile.XcodeProjFileError)
      if let parserError = error as? XcodeProjFile.XcodeProjFileError {
        XCTAssertEqual(parserError, .targetNotFound)
        XCTAssertEqual(parserError.localizedDescription, "Target not found")
      }
    }

    let result = try isFileExist(proj: mockProject, target: "Example", name: fileName)
    XCTAssertFalse(result)
  }

  func testAddFile_throwsError_whenMainGroupNotFound() throws {
    // Arrange
    let fileName = "Dependencies.swift"
    let mockProject = try createTemporaryProject()
    mockProject.pbxproj.rootObject = nil

    let xcodeProjFile = try XcodeProjFile(
      project: mockProject,
      xcodeProjPath: projectPath,
      target: "Example"
    )

    // Act & Assert
    XCTAssertThrowsError(try xcodeProjFile.createFile(name: fileName, content: "")) { error in
      XCTAssertTrue(error is XcodeProjFile.XcodeProjFileError)
      if let parserError = error as? XcodeProjFile.XcodeProjFileError {
        XCTAssertEqual(parserError, .malformedXcodeProjFile)
        XCTAssertEqual(parserError.localizedDescription, "Malformed XcodeProj file")
      }
    }

    let result = try isFileExist(proj: mockProject, target: "Example", name: fileName)
    XCTAssertFalse(result)
  }
}

private extension XcodeProjFileTests {
  func isFileExist(proj: XcodeProj, target: String, name: String) throws -> Bool {
    try proj.pbxproj
      .nativeTargets
      .first { $0.name == target }?
      .sourceFiles()
      .contains { $0.path == name } ?? false
  }

  func createTemporaryProject() throws -> XcodeProj {
    // Create directory
    try FileManager.default.createDirectory(at: projectPath.url, withIntermediateDirectories: true)

    // Create a minimal pbxproj file
    let pbxprojPath = projectPath.url.appendingPathComponent("project.pbxproj")
    let minimalProject = """
      // !$*UTF8*$!
      {
          archiveVersion = 1;
          classes = {
          };
          objectVersion = 77;
          objects = {

      /* Begin PBXBuildFile section */
              F799973D2EE07B1A002DBC9D /* Analytics in Frameworks */ = {isa = PBXBuildFile; productRef = F799973C2EE07B1A002DBC9D /* Analytics */; };
              F7D5F3DF2EE45BC00038CA72 /* MoreLocalService.swift in Sources */ = {isa = PBXBuildFile; fileRef = F7D5F3D72EE45BC00038CA72 /* MoreLocalService.swift */; };
              F7D5F3E22EE45BC00038CA72 /* MoreRepository.swift in Sources */ = {isa = PBXBuildFile; fileRef = F7D5F3DD2EE45BC00038CA72 /* MoreRepository.swift */; };
              F7D5F3E52EE45BC00038CA72 /* MoreCoordinator.swift in Sources */ = {isa = PBXBuildFile; fileRef = F7D5F3D92EE45BC00038CA72 /* MoreCoordinator.swift */; };
              F7D5F3F42EE5987E0038CA72 /* Core in Frameworks */ = {isa = PBXBuildFile; productRef = F7D5F3F32EE5987E0038CA72 /* Core */; };
              F7D5F4022EE61C660038CA72 /* MoreManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = F70B1C282EDF83D000CB0471 /* MoreManager.swift */; };
              F7D5F4032EE61C660038CA72 /* MoreFactory.swift in Sources */ = {isa = PBXBuildFile; fileRef = F7D5F3FD2EE61A120038CA72 /* MoreFactory.swift */; };
              F7D5F4042EE61C660038CA72 /* MoreViewControllerWrapper.swift in Sources */ = {isa = PBXBuildFile; fileRef = F7D5F3FE2EE61A120038CA72 /* MoreViewControllerWrapper.swift */; };
              F7D5F4052EE61C660038CA72 /* MoreRemoteService.swift in Sources */ = {isa = PBXBuildFile; fileRef = F70B1C272EDF83C900CB0471 /* MoreRemoteService.swift */; };
              F7D5F4062EE61C660038CA72 /* MoreViewController.swift in Sources */ = {isa = PBXBuildFile; fileRef = F70B1C292EDF83DB00CB0471 /* MoreViewController.swift */; };
              F7D5F4072EE61C660038CA72 /* MoreModule.swift in Sources */ = {isa = PBXBuildFile; fileRef = F70B1C242EDF836700CB0471 /* MoreModule.swift */; };
              F7D5F4082EE61C660038CA72 /* MoreViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = F70B1C232EDF82EC00CB0471 /* MoreViewModel.swift */; };
              F7DFCCBE2F046542004E8489 /* Arrow in Frameworks */ = {isa = PBXBuildFile; productRef = F7DFCCBD2F046542004E8489 /* Arrow */; };
              F7DFCCE22F0527C3004E8489 /* dependencies.generated.swift in Sources */ = {isa = PBXBuildFile; fileRef = F7DFCCE12F0527C3004E8489 /* dependencies.generated.swift */; };
      /* End PBXBuildFile section */

      /* Begin PBXFileReference section */
              F70B1C132EDF7C1C00CB0471 /* Example.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Example.app; sourceTree = BUILT_PRODUCTS_DIR; };
              F70B1C232EDF82EC00CB0471 /* MoreViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreViewModel.swift; sourceTree = "<group>"; };
              F70B1C242EDF836700CB0471 /* MoreModule.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreModule.swift; sourceTree = "<group>"; };
              F70B1C272EDF83C900CB0471 /* MoreRemoteService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreRemoteService.swift; sourceTree = "<group>"; };
              F70B1C282EDF83D000CB0471 /* MoreManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreManager.swift; sourceTree = "<group>"; };
              F70B1C292EDF83DB00CB0471 /* MoreViewController.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreViewController.swift; sourceTree = "<group>"; };
              F7D5F3D72EE45BC00038CA72 /* MoreLocalService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreLocalService.swift; sourceTree = "<group>"; };
              F7D5F3D92EE45BC00038CA72 /* MoreCoordinator.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreCoordinator.swift; sourceTree = "<group>"; };
              F7D5F3DD2EE45BC00038CA72 /* MoreRepository.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreRepository.swift; sourceTree = "<group>"; };
              F7D5F3FD2EE61A120038CA72 /* MoreFactory.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreFactory.swift; sourceTree = "<group>"; };
              F7D5F3FE2EE61A120038CA72 /* MoreViewControllerWrapper.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MoreViewControllerWrapper.swift; sourceTree = "<group>"; };
              F7DFCCE12F0527C3004E8489 /* dependencies.generated.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = dependencies.generated.swift; sourceTree = "<group>"; };
      /* End PBXFileReference section */

      /* Begin PBXFileSystemSynchronizedRootGroup section */
              F70B1C152EDF7C1C00CB0471 /* Example */ = {
                  isa = PBXFileSystemSynchronizedRootGroup;
                  path = Example;
                  sourceTree = "<group>";
              };
              F70B1C3C2EDF8C3B00CB0471 /* Dependencies */ = {
                  isa = PBXFileSystemSynchronizedRootGroup;
                  path = Dependencies;
                  sourceTree = "<group>";
              };
      /* End PBXFileSystemSynchronizedRootGroup section */

      /* Begin PBXFrameworksBuildPhase section */
              F70B1C102EDF7C1C00CB0471 /* Frameworks */ = {
                  isa = PBXFrameworksBuildPhase;
                  buildActionMask = 2147483647;
                  files = (
                      F7DFCCBE2F046542004E8489 /* Arrow in Frameworks */,
                      F799973D2EE07B1A002DBC9D /* Analytics in Frameworks */,
                      F7D5F3F42EE5987E0038CA72 /* Core in Frameworks */,
                  );
                  runOnlyForDeploymentPostprocessing = 0;
              };
      /* End PBXFrameworksBuildPhase section */

      /* Begin PBXGroup section */
              F70B1C0A2EDF7C1C00CB0471 = {
                  isa = PBXGroup;
                  children = (
                      F7DFCCE12F0527C3004E8489 /* dependencies.generated.swift */,
                      F70B1C3C2EDF8C3B00CB0471 /* Dependencies */,
                      F70B1C212EDF820700CB0471 /* More */,
                      F70B1C152EDF7C1C00CB0471 /* Example */,
                      F70B1C142EDF7C1C00CB0471 /* Products */,
                  );
                  sourceTree = "<group>";
              };
              F70B1C142EDF7C1C00CB0471 /* Products */ = {
                  isa = PBXGroup;
                  children = (
                      F70B1C132EDF7C1C00CB0471 /* Example.app */,
                  );
                  name = Products;
                  sourceTree = "<group>";
              };
              F70B1C212EDF820700CB0471 /* More */ = {
                  isa = PBXGroup;
                  children = (
                      F7D5F3FD2EE61A120038CA72 /* MoreFactory.swift */,
                      F7D5F3FE2EE61A120038CA72 /* MoreViewControllerWrapper.swift */,
                      F7D5F3D72EE45BC00038CA72 /* MoreLocalService.swift */,
                      F7D5F3D92EE45BC00038CA72 /* MoreCoordinator.swift */,
                      F7D5F3DD2EE45BC00038CA72 /* MoreRepository.swift */,
                      F70B1C292EDF83DB00CB0471 /* MoreViewController.swift */,
                      F70B1C282EDF83D000CB0471 /* MoreManager.swift */,
                      F70B1C272EDF83C900CB0471 /* MoreRemoteService.swift */,
                      F70B1C242EDF836700CB0471 /* MoreModule.swift */,
                      F70B1C232EDF82EC00CB0471 /* MoreViewModel.swift */,
                  );
                  path = More;
                  sourceTree = "<group>";
              };
      /* End PBXGroup section */

      /* Begin PBXNativeTarget section */
              F70B1C122EDF7C1C00CB0471 /* Example */ = {
                  isa = PBXNativeTarget;
                  buildConfigurationList = F70B1C1E2EDF7C1D00CB0471 /* Build configuration list for PBXNativeTarget "Example" */;
                  buildPhases = (
                      F70B1C0F2EDF7C1C00CB0471 /* Sources */,
                      F70B1C102EDF7C1C00CB0471 /* Frameworks */,
                      F70B1C112EDF7C1C00CB0471 /* Resources */,
                  );
                  buildRules = (
                  );
                  dependencies = (
                  );
                  fileSystemSynchronizedGroups = (
                      F70B1C152EDF7C1C00CB0471 /* Example */,
                      F70B1C3C2EDF8C3B00CB0471 /* Dependencies */,
                  );
                  name = Example;
                  packageProductDependencies = (
                      F799973C2EE07B1A002DBC9D /* Analytics */,
                      F7D5F3F32EE5987E0038CA72 /* Core */,
                      F7DFCCBD2F046542004E8489 /* Arrow */,
                  );
                  productName = Example;
                  productReference = F70B1C132EDF7C1C00CB0471 /* Example.app */;
                  productType = "com.apple.product-type.application";
              };
      /* End PBXNativeTarget section */

      /* Begin PBXProject section */
              F70B1C0B2EDF7C1C00CB0471 /* Project object */ = {
                  isa = PBXProject;
                  attributes = {
                      BuildIndependentTargetsInParallel = 1;
                      LastSwiftUpdateCheck = 2610;
                      LastUpgradeCheck = 2610;
                      TargetAttributes = {
                          F70B1C122EDF7C1C00CB0471 = {
                              CreatedOnToolsVersion = 26.1.1;
                          };
                      };
                  };
                  buildConfigurationList = F70B1C0E2EDF7C1C00CB0471 /* Build configuration list for PBXProject "Example" */;
                  developmentRegion = en;
                  hasScannedForEncodings = 0;
                  knownRegions = (
                      en,
                      Base,
                  );
                  mainGroup = F70B1C0A2EDF7C1C00CB0471;
                  minimizedProjectReferenceProxies = 1;
                  packageReferences = (
                      F7DFCCBC2F046542004E8489 /* XCRemoteSwiftPackageReference "arrow" */,
                      F799973B2EE07B1A002DBC9D /* XCLocalSwiftPackageReference "Analytics" */,
                  );
                  preferredProjectObjectVersion = 77;
                  productRefGroup = F70B1C142EDF7C1C00CB0471 /* Products */;
                  projectDirPath = "";
                  projectRoot = "";
                  targets = (
                      F70B1C122EDF7C1C00CB0471 /* Example */,
                  );
              };
      /* End PBXProject section */

      /* Begin PBXResourcesBuildPhase section */
              F70B1C112EDF7C1C00CB0471 /* Resources */ = {
                  isa = PBXResourcesBuildPhase;
                  buildActionMask = 2147483647;
                  files = (
                  );
                  runOnlyForDeploymentPostprocessing = 0;
              };
      /* End PBXResourcesBuildPhase section */

      /* Begin PBXSourcesBuildPhase section */
              F70B1C0F2EDF7C1C00CB0471 /* Sources */ = {
                  isa = PBXSourcesBuildPhase;
                  buildActionMask = 2147483647;
                  files = (
                      F7DFCCE22F0527C3004E8489 /* dependencies.generated.swift in Sources */,
                      F7D5F4022EE61C660038CA72 /* MoreManager.swift in Sources */,
                      F7D5F4032EE61C660038CA72 /* MoreFactory.swift in Sources */,
                      F7D5F4042EE61C660038CA72 /* MoreViewControllerWrapper.swift in Sources */,
                      F7D5F4052EE61C660038CA72 /* MoreRemoteService.swift in Sources */,
                      F7D5F4062EE61C660038CA72 /* MoreViewController.swift in Sources */,
                      F7D5F4072EE61C660038CA72 /* MoreModule.swift in Sources */,
                      F7D5F4082EE61C660038CA72 /* MoreViewModel.swift in Sources */,
                      F7D5F3DF2EE45BC00038CA72 /* MoreLocalService.swift in Sources */,
                      F7D5F3E22EE45BC00038CA72 /* MoreRepository.swift in Sources */,
                      F7D5F3E52EE45BC00038CA72 /* MoreCoordinator.swift in Sources */,
                  );
                  runOnlyForDeploymentPostprocessing = 0;
              };
      /* End PBXSourcesBuildPhase section */

      /* Begin XCBuildConfiguration section */
              F70B1C1C2EDF7C1D00CB0471 /* Debug */ = {
                  isa = XCBuildConfiguration;
                  buildSettings = {
                      ALWAYS_SEARCH_USER_PATHS = NO;
                      ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
                      CLANG_ANALYZER_NONNULL = YES;
                      CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
                      CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                      CLANG_ENABLE_MODULES = YES;
                      CLANG_ENABLE_OBJC_ARC = YES;
                      CLANG_ENABLE_OBJC_WEAK = YES;
                      CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
                      CLANG_WARN_BOOL_CONVERSION = YES;
                      CLANG_WARN_COMMA = YES;
                      CLANG_WARN_CONSTANT_CONVERSION = YES;
                      CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
                      CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
                      CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
                      CLANG_WARN_EMPTY_BODY = YES;
                      CLANG_WARN_ENUM_CONVERSION = YES;
                      CLANG_WARN_INFINITE_RECURSION = YES;
                      CLANG_WARN_INT_CONVERSION = YES;
                      CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
                      CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
                      CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
                      CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
                      CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
                      CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
                      CLANG_WARN_STRICT_PROTOTYPES = YES;
                      CLANG_WARN_SUSPICIOUS_MOVE = YES;
                      CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
                      CLANG_WARN_UNREACHABLE_CODE = YES;
                      CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
                      COPY_PHASE_STRIP = NO;
                      DEBUG_INFORMATION_FORMAT = dwarf;
                      ENABLE_STRICT_OBJC_MSGSEND = YES;
                      ENABLE_TESTABILITY = YES;
                      ENABLE_USER_SCRIPT_SANDBOXING = YES;
                      GCC_C_LANGUAGE_STANDARD = gnu17;
                      GCC_DYNAMIC_NO_PIC = NO;
                      GCC_NO_COMMON_BLOCKS = YES;
                      GCC_OPTIMIZATION_LEVEL = 0;
                      GCC_PREPROCESSOR_DEFINITIONS = (
                          "DEBUG=1",
                          "$(inherited)",
                      );
                      GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
                      GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
                      GCC_WARN_UNDECLARED_SELECTOR = YES;
                      GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
                      GCC_WARN_UNUSED_FUNCTION = YES;
                      GCC_WARN_UNUSED_VARIABLE = YES;
                      IPHONEOS_DEPLOYMENT_TARGET = 26.1;
                      LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
                      MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
                      MTL_FAST_MATH = YES;
                      ONLY_ACTIVE_ARCH = YES;
                      SDKROOT = iphoneos;
                      SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
                      SWIFT_OPTIMIZATION_LEVEL = "-Onone";
                  };
                  name = Debug;
              };
              F70B1C1D2EDF7C1D00CB0471 /* Release */ = {
                  isa = XCBuildConfiguration;
                  buildSettings = {
                      ALWAYS_SEARCH_USER_PATHS = NO;
                      ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
                      CLANG_ANALYZER_NONNULL = YES;
                      CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
                      CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                      CLANG_ENABLE_MODULES = YES;
                      CLANG_ENABLE_OBJC_ARC = YES;
                      CLANG_ENABLE_OBJC_WEAK = YES;
                      CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
                      CLANG_WARN_BOOL_CONVERSION = YES;
                      CLANG_WARN_COMMA = YES;
                      CLANG_WARN_CONSTANT_CONVERSION = YES;
                      CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
                      CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
                      CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
                      CLANG_WARN_EMPTY_BODY = YES;
                      CLANG_WARN_ENUM_CONVERSION = YES;
                      CLANG_WARN_INFINITE_RECURSION = YES;
                      CLANG_WARN_INT_CONVERSION = YES;
                      CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
                      CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
                      CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
                      CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
                      CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
                      CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
                      CLANG_WARN_STRICT_PROTOTYPES = YES;
                      CLANG_WARN_SUSPICIOUS_MOVE = YES;
                      CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
                      CLANG_WARN_UNREACHABLE_CODE = YES;
                      CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
                      COPY_PHASE_STRIP = NO;
                      DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
                      ENABLE_NS_ASSERTIONS = NO;
                      ENABLE_STRICT_OBJC_MSGSEND = YES;
                      ENABLE_USER_SCRIPT_SANDBOXING = YES;
                      GCC_C_LANGUAGE_STANDARD = gnu17;
                      GCC_NO_COMMON_BLOCKS = YES;
                      GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
                      GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
                      GCC_WARN_UNDECLARED_SELECTOR = YES;
                      GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
                      GCC_WARN_UNUSED_FUNCTION = YES;
                      GCC_WARN_UNUSED_VARIABLE = YES;
                      IPHONEOS_DEPLOYMENT_TARGET = 26.1;
                      LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
                      MTL_ENABLE_DEBUG_INFO = NO;
                      MTL_FAST_MATH = YES;
                      SDKROOT = iphoneos;
                      SWIFT_COMPILATION_MODE = wholemodule;
                      VALIDATE_PRODUCT = YES;
                  };
                  name = Release;
              };
              F70B1C1F2EDF7C1D00CB0471 /* Debug */ = {
                  isa = XCBuildConfiguration;
                  buildSettings = {
                      ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                      ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
                      CODE_SIGN_STYLE = Automatic;
                      CURRENT_PROJECT_VERSION = 1;
                      ENABLE_PREVIEWS = YES;
                      ENABLE_USER_SCRIPT_SANDBOXING = YES;
                      GENERATE_INFOPLIST_FILE = YES;
                      INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
                      INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
                      INFOPLIST_KEY_UILaunchScreen_Generation = YES;
                      INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
                      INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown";
                      LD_RUNPATH_SEARCH_PATHS = (
                          "$(inherited)",
                          "@executable_path/Frameworks",
                      );
                      MARKETING_VERSION = 1.0;
                      PRODUCT_BUNDLE_IDENTIFIER = com.aostudio.arrow.Example;
                      PRODUCT_NAME = "$(TARGET_NAME)";
                      STRING_CATALOG_GENERATE_SYMBOLS = YES;
                      SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
                      SUPPORTS_MACCATALYST = NO;
                      SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
                      SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;
                      SWIFT_APPROACHABLE_CONCURRENCY = YES;
                      SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
                      SWIFT_EMIT_LOC_STRINGS = YES;
                      SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
                      SWIFT_VERSION = 5.0;
                      TARGETED_DEVICE_FAMILY = 1;
                  };
                  name = Debug;
              };
              F70B1C202EDF7C1D00CB0471 /* Release */ = {
                  isa = XCBuildConfiguration;
                  buildSettings = {
                      ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                      ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
                      CODE_SIGN_STYLE = Automatic;
                      CURRENT_PROJECT_VERSION = 1;
                      ENABLE_PREVIEWS = YES;
                      ENABLE_USER_SCRIPT_SANDBOXING = YES;
                      GENERATE_INFOPLIST_FILE = YES;
                      INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
                      INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
                      INFOPLIST_KEY_UILaunchScreen_Generation = YES;
                      INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
                      INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown";
                      LD_RUNPATH_SEARCH_PATHS = (
                          "$(inherited)",
                          "@executable_path/Frameworks",
                      );
                      MARKETING_VERSION = 1.0;
                      PRODUCT_BUNDLE_IDENTIFIER = com.aostudio.arrow.Example;
                      PRODUCT_NAME = "$(TARGET_NAME)";
                      STRING_CATALOG_GENERATE_SYMBOLS = YES;
                      SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
                      SUPPORTS_MACCATALYST = NO;
                      SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
                      SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;
                      SWIFT_APPROACHABLE_CONCURRENCY = YES;
                      SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
                      SWIFT_EMIT_LOC_STRINGS = YES;
                      SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
                      SWIFT_VERSION = 5.0;
                      TARGETED_DEVICE_FAMILY = 1;
                  };
                  name = Release;
              };
      /* End XCBuildConfiguration section */

      /* Begin XCConfigurationList section */
              F70B1C0E2EDF7C1C00CB0471 /* Build configuration list for PBXProject "Example" */ = {
                  isa = XCConfigurationList;
                  buildConfigurations = (
                      F70B1C1C2EDF7C1D00CB0471 /* Debug */,
                      F70B1C1D2EDF7C1D00CB0471 /* Release */,
                  );
                  defaultConfigurationIsVisible = 0;
                  defaultConfigurationName = Release;
              };
              F70B1C1E2EDF7C1D00CB0471 /* Build configuration list for PBXNativeTarget "Example" */ = {
                  isa = XCConfigurationList;
                  buildConfigurations = (
                      F70B1C1F2EDF7C1D00CB0471 /* Debug */,
                      F70B1C202EDF7C1D00CB0471 /* Release */,
                  );
                  defaultConfigurationIsVisible = 0;
                  defaultConfigurationName = Release;
              };
      /* End XCConfigurationList section */

      /* Begin XCLocalSwiftPackageReference section */
              F799973B2EE07B1A002DBC9D /* XCLocalSwiftPackageReference "Analytics" */ = {
                  isa = XCLocalSwiftPackageReference;
                  relativePath = Analytics;
              };
      /* End XCLocalSwiftPackageReference section */

      /* Begin XCRemoteSwiftPackageReference section */
              F7DFCCBC2F046542004E8489 /* XCRemoteSwiftPackageReference "arrow" */ = {
                  isa = XCRemoteSwiftPackageReference;
                  repositoryURL = "https://github.com/AhmedOsman00/arrow";
                  requirement = {
                      kind = exactVersion;
                      version = 1.0.0;
                  };
              };
      /* End XCRemoteSwiftPackageReference section */

      /* Begin XCSwiftPackageProductDependency section */
              F799973C2EE07B1A002DBC9D /* Analytics */ = {
                  isa = XCSwiftPackageProductDependency;
                  productName = Analytics;
              };
              F7D5F3F32EE5987E0038CA72 /* Core */ = {
                  isa = XCSwiftPackageProductDependency;
                  productName = Core;
              };
              F7DFCCBD2F046542004E8489 /* Arrow */ = {
                  isa = XCSwiftPackageProductDependency;
                  package = F7DFCCBC2F046542004E8489 /* XCRemoteSwiftPackageReference "arrow" */;
                  productName = Arrow;
              };
      /* End XCSwiftPackageProductDependency section */
          };
          rootObject = F70B1C0B2EDF7C1C00CB0471 /* Project object */;
      }

      """

    try minimalProject.write(to: pbxprojPath, atomically: true, encoding: .utf8)
    return try XcodeProj(path: projectPath)
  }
}
