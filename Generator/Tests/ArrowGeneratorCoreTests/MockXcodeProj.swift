import Foundation
import XcodeProj
import PathKit
@testable import ArrowGeneratorCore

final class MockXcodeProj: XcodeFileParsing {
    private let targetName: String
    private let swiftFiles: [String]
    private let otherFiles: [String]
    private let hasMainGroup: Bool
    private let _pbxproj: PBXProj

    var writeWasCalled = false

    var pbxproj: PBXProj {
        return _pbxproj
    }

    init(targetName: String, swiftFiles: [String], otherFiles: [String], hasMainGroup: Bool = true) throws {
        self.targetName = targetName
        self.swiftFiles = swiftFiles
        self.otherFiles = otherFiles
        self.hasMainGroup = hasMainGroup

        // Create and configure a complete PBXProj structure
        let tempProj = try Self.createTemporaryProject()
        self._pbxproj = tempProj.pbxproj

        setupMockProject()
    }

    required init(path: Path) throws {
        self.targetName = ""
        self.swiftFiles = []
        self.otherFiles = []
        self.hasMainGroup = true
        self._pbxproj = PBXProj()
    }

    func write(path: Path, override: Bool) throws {
        writeWasCalled = true
    }

    private func setupMockProject() {
        // Get the root objects from the pbxproj
        let rootProject = _pbxproj.rootObject
        let mainGroup = rootProject?.mainGroup

        // Create target
        let target = PBXNativeTarget(name: targetName)
        _pbxproj.add(object: target)
        rootProject?.targets.append(target)

        // Create sources build phase
        let sourcesBuildPhase = PBXSourcesBuildPhase()
        _pbxproj.add(object: sourcesBuildPhase)
        target.buildPhases.append(sourcesBuildPhase)

        // Add all files
        let allFiles = swiftFiles + otherFiles
        for fileName in allFiles {
            let fileRef = PBXFileReference(
                sourceTree: .group,
                name: fileName,
                path: fileName
            )
            _pbxproj.add(object: fileRef)
            mainGroup?.children.append(fileRef)

            let buildFile = PBXBuildFile(file: fileRef)
            _pbxproj.add(object: buildFile)
            sourcesBuildPhase.files?.append(buildFile)
        }

        // Remove root object if hasMainGroup is false
        if !hasMainGroup {
            _pbxproj.rootObject = nil
        }
    }

    private static func createTemporaryProject() throws -> XcodeProj {
        // Create a minimal temporary Xcode project
        let tempDir = FileManager.default.temporaryDirectory
        let projectPath = tempDir.appendingPathComponent("MockProject_\(UUID().uuidString).xcodeproj")

        // Create directory
        try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)

        // Create a minimal pbxproj file
        let pbxprojPath = projectPath.appendingPathComponent("project.pbxproj")
        let minimalProject = """
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            classes = {
            };
            objectVersion = 46;
            objects = {
                MAINGROUP = {
                    isa = PBXGroup;
                    children = ();
                    sourceTree = "<group>";
                };
                PROJECT = {
                    isa = PBXProject;
                    attributes = {};
                    buildConfigurationList = CONFIGLIST;
                    compatibilityVersion = "Xcode 3.2";
                    developmentRegion = English;
                    hasScannedForEncodings = 0;
                    knownRegions = (en);
                    mainGroup = MAINGROUP;
                    productRefGroup = MAINGROUP;
                    projectDirPath = "";
                    projectRoot = "";
                    targets = ();
                };
                CONFIGLIST = {
                    isa = XCConfigurationList;
                    buildConfigurations = ();
                    defaultConfigurationIsVisible = 0;
                    defaultConfigurationName = Release;
                };
            };
            rootObject = PROJECT;
        }
        """

        try minimalProject.write(to: pbxprojPath, atomically: true, encoding: .utf8)

        // Load and return the project
        let xcodeProj = try XcodeProj(path: Path(projectPath.path))

        // Clean up
        try? FileManager.default.removeItem(at: projectPath)

        return xcodeProj
    }
}
