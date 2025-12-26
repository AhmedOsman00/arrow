import Core

final class MoreRemoteService: Service {
  let network: Networking?

  init(network: Networking) {
    self.network = network
  }

  func fetchData() async throws -> String {
    try await "Data from \(type(of: self)): \(network?.fetchData() ?? "No network")"
  }
}
