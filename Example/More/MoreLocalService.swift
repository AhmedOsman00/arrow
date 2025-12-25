protocol Service {
    func fetchData() async throws -> String
}

final class MoreLocalService: Service {
    let message: String

    init(message: String) {
        self.message = message
    }

    func fetchData() async throws -> String {
        "Data from \(type(of: self)): \(message)"
    }
}
