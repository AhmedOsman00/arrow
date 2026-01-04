import PathKit
import XcodeProj

protocol XcodeProjProtocol {
  var pbxproj: PBXProj { get }

  init(path: Path) throws
  func write(path: Path, override: Bool) throws
}

extension XcodeProj: XcodeProjProtocol {}
