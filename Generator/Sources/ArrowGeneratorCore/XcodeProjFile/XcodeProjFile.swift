import Foundation
import PathKit
import XcodeProj

final class XcodeProjFile {
    private let xcodeProjPath: Path
    private let target: String
    private let project: XcodeProjProtocol

    private var sourceRoot: Path {
        xcodeProjPath.parent()
    }

    private var pbxproj: PBXProj {
        project.pbxproj
    }

    private var mainTarget: PBXTarget? {
        pbxproj.nativeTargets.first { $0.name == target }
    }

    init(
        project: XcodeProjProtocol,
        xcodeProjPath: Path,
        target: String
    ) throws {
        self.xcodeProjPath = xcodeProjPath
        self.target = target
        self.project = project
    }

    func createFile(name: String, content: String) throws {
        guard let mainTarget else {
            throw XcodeProjFileError.targetNotFound
        }

        guard let main = pbxproj.rootObject?.mainGroup else {
            throw XcodeProjFileError.malformedXcodeProjFile
        }

        let filePath = sourceRoot + Path(name)
        try content.write(to: filePath.url, atomically: true, encoding: .utf8)
        let fileRef = try main.addFile(at: filePath, sourceRoot: sourceRoot)
        _ = try mainTarget.sourcesBuildPhase()?.add(file: fileRef)
        try project.write(path: xcodeProjPath, override: true)
    }

    enum XcodeProjFileError: LocalizedError {
        case targetNotFound
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
