import Foundation

public protocol Networking {
    func fetchData() async throws -> String
}

final class NetworkingImpl: Networking {
    func fetchData() async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "Hello, World!"
    }
}
