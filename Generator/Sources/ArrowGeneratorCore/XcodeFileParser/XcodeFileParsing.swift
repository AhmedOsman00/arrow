import XcodeProj
import PathKit

protocol XcodeFileParsing {
    var pbxproj: PBXProj { get }
    
    init(path: Path) throws
    func write(path: Path, override: Bool) throws
}

extension XcodeProj: XcodeFileParsing {}
