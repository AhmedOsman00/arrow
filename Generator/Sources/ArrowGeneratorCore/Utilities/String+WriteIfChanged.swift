import Foundation

extension String {
  /// Writes the string only when the file's content differs, so an unchanged file keeps its
  /// modification date and doesn't trigger a recompile on every build.
  ///
  /// - Returns: Whether the file was written.
  @discardableResult
  func writeIfChanged(toFile path: String) throws -> Bool {
    if let existing = try? String(contentsOfFile: path, encoding: .utf8), existing == self {
      return false
    }
    try write(toFile: path, atomically: true, encoding: .utf8)
    return true
  }
}
