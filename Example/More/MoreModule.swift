import Arrow
import ArrowMacros
import Core
import Analytics

final class MoreModule: TransientScope {
    var provideMoreLocalService: MoreLocalService {
        MoreLocalService(message: "Local Hello World!")
    }

    @Name("MainManager")
    var provideMainFactory: MoreManagerProtocol {
        MoreManager(id: "Main")
    }

    func provideMoreRemoteService(network: Networking) -> MoreRemoteService {
        MoreRemoteService(network: network)
    }

    func provideRepository(localService: MoreLocalService,
                           remoteService: MoreRemoteService,
                           loggerFactory: LoggerFactory) -> MoreRepositoryProtocol {
        MoreRepository(localService: localService,
                       remoteService: remoteService,
                       logger: loggerFactory("[More]"))
    }

    @Name("MoreManager")
    func provideMoreFactory(id: String = "More") -> MoreManagerProtocol {
        MoreManager(id: id)
    }

    func provideViewModel(@Named("MainManager") mainManager: MoreManagerProtocol,
                          @Named("MoreManager") moreManager: MoreManagerProtocol,
                          _ moreRepository: MoreRepositoryProtocol,
                          analytics: Analytics) -> MoreViewModel {
        MoreViewModel(mainManager: mainManager,
                      moreManager: moreManager,
                      moreRepository: moreRepository,
                      analytics: analytics)
    }
}
