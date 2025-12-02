import Foundation
import XcodeProj
import PathKit

final class XcodeFileParser {
    private let xcodeProjPath: Path
    private let target: String
    private let project: XcodeFileParsing

    private var sourceRoot: Path {
        xcodeProjPath.parent()
    }

    private var pbxproj: PBXProj {
        project.pbxproj
    }

    private var mainTarget: PBXTarget? {
        pbxproj.nativeTargets.first { $0.name == target }
    }

    init(project: XcodeFileParsing,
         xcodeProjPath: Path,
         target: String) throws {
        self.xcodeProjPath = xcodeProjPath
        self.target = target
        self.project = project
    }

    func parse() throws -> [String] {
        return try mainTarget?
            .sourceFiles()
            .compactMap {  try? $0.fullPath(sourceRoot: sourceRoot.string) }
            .filter { $0.hasSuffix(".swift") } ?? []
    }

    func isFileAlreadyAdded(path: String) throws -> Bool {
        try mainTarget?.sourceFiles().contains { $0.path == path } ?? false
    }

    func addFile(path: String) throws {
        guard let mainTarget else{
            throw XcodeParserError.targetNotFound
        }

        guard let main = pbxproj.rootObject?.mainGroup else {
            throw XcodeParserError.malformedXcodeProjFile
        }

        let fileRef = try main.addFile(at: Path(path), sourceRoot: sourceRoot)
        let _ = try mainTarget.sourcesBuildPhase()?.add(file: fileRef)
        try project.write(path: xcodeProjPath, override: true)
    }

    enum XcodeParserError: Error {
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
