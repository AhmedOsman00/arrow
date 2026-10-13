import Foundation

struct FileUiModel {
  let imports: [String]
  let dependencies: [DependencyUiModel]

  var modules: [String] {
    var seen = Set<String>()
    return dependencies.map(\.module).filter { seen.insert($0).inserted }
  }
}
