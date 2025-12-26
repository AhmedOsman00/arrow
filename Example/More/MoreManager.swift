protocol MoreManagerProtocol {
  var id: String { get }
}

final class MoreManager: MoreManagerProtocol {
  let id: String

  init(id: String) {
    self.id = id
  }
}
