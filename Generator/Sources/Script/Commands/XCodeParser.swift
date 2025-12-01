import Foundation
import XcodeProj
import PathKit

protocol XcodeProjParserProtocol {
    var pbxproj: PBXProj { get }
    
    init(path: Path) throws
    func write(path: Path, override: Bool) throws
}

extension XcodeProj: XcodeProjParserProtocol {}

final class XCodeParser {
    private let xcodeProjPath: Path
    private let target: String
    private let sourceRoot: String
    private let project: XcodeProjParserProtocol

    private var pbxproj: PBXProj {
        project.pbxproj
    }

    private var mainTarget: PBXTarget? {
        pbxproj.nativeTargets.first { $0.name == target }
    }

    init(project: XcodeProjParserProtocol,
         xcodeProjPath: Path,
         sourceRoot: String,
         target: String) throws {
        self.xcodeProjPath = xcodeProjPath
        self.target = target
        self.sourceRoot = sourceRoot
        self.project = project
    }

    func parse() throws -> [String] {
        return try mainTarget?
            .sourceFiles()
            .compactMap {  try? $0.fullPath(sourceRoot: sourceRoot) }
            .filter { $0.hasSuffix(".swift") } ?? []
    }

    func isFileAlreadyAdded(path: String) throws -> Bool {
        try mainTarget?.sourceFiles().contains { $0.path == path } ?? false
    }

    func addFile(path: String) throws {
        guard let mainTarget, let main = pbxproj.rootObject?.mainGroup else {
            throw XcodeParserError.targetNotFound
        }

        let fileRef = try main.addFile(at: Path(path), sourceRoot: Path(sourceRoot))
        let _ = try mainTarget.sourcesBuildPhase()?.add(file: fileRef)
        try project.write(path: xcodeProjPath, override: true)
    }

    enum XcodeParserError: Error {
        case targetNotFound

        var localizedDescription: String {
            switch self {
            case .targetNotFound:
                return "Target not found"
            }
        }
    }
}
