import Foundation
import XcodeProj
import PathKit

final class XCodeParser {
    static let fileName = "dependencies.generated.swift"
    private let path: Path
    private let source: String
    private let target: String
    private let project: XcodeProj
    private var pbxproj: PBXProj {
        project.pbxproj
    }

    init(path: Path, source: String, target: String) throws {
        self.path = path
        self.source = source
        self.target = target
        self.project = try XcodeProj(path: path)
    }

    func parse() -> [String] {
        return pbxproj
            .nativeTargets
            .compactMap { try? $0.sourceFiles() }
            .flatMap { $0 }
            .compactMap {  try? $0.fullPath(sourceRoot: source) }
            .filter { $0.hasSuffix(".swift") }
    }

    func addDependenciesFile() throws {
        guard let main = pbxproj.rootObject?.mainGroup,
              let target = pbxproj.nativeTargets.first(where: { $0.name == target })
        else {
            throw NSError()
        }

        guard try !target.sourceFiles().contains(where: { $0.path == Self.fileName }) else {
            return
        }

        let fileRef = try main.addFile(at: Path("\(source)/\(Self.fileName)"), sourceRoot: Path(source))
        let _ = try target.sourcesBuildPhase()?.add(file: fileRef)
        try project.write(path: path)
    }
}
