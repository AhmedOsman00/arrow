import Core

protocol MoreRepositoryProtocol {
    func fetchData(fromCache: Bool) async throws -> String
}

final class MoreRepository: MoreRepositoryProtocol {
    let localService: Service
    let remoteService: Service
    let logger: Logger?

    init(localService: Service, remoteService: Service, logger: Logger? = nil) {
        self.localService = localService
        self.remoteService = remoteService
        self.logger = logger
    }

    func fetchData(fromCache: Bool = false) async throws -> String {
        if fromCache {
            return try await localService.fetchData()
        }

        return try await remoteService.fetchData()
    }
}
