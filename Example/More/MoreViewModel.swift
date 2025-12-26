import Arrow
import ArrowMacros
import Analytics
import Foundation

protocol MoreViewModelProtocol {
  func getFactoryInfo() -> String
  func fetchLocalData() async throws -> String
  func fetchRemoteData() async throws -> String
}

final class MoreViewModel: MoreViewModelProtocol {
  let mainManager: MoreManagerProtocol
  let moreManager: MoreManagerProtocol
  let moreRepository: MoreRepositoryProtocol
  let analytics: Analytics

  init(
    mainManager: MoreManagerProtocol,
    moreManager: MoreManagerProtocol,
    moreRepository: MoreRepositoryProtocol,
    analytics: Analytics
  ) {
    self.mainManager = mainManager
    self.moreManager = moreManager
    self.moreRepository = moreRepository
    self.analytics = analytics
  }

  func getFactoryInfo() -> String {
    analytics.logEvent(
      "factory_info_requested",
      parameters: [
        "main_factory_id": mainManager.id,
        "more_factory_id": moreManager.id,
      ])

    return """
      Factory Information:
      - Main Factory ID: \(mainManager.id)
      - More Factory ID: \(moreManager.id)
      """
  }

  func fetchLocalData() async throws -> String {
    analytics.logEvent("fetch_local_data_started", parameters: nil)

    do {
      let data = try await moreRepository.fetchData(fromCache: true)
      analytics.logEvent(
        "fetch_local_data_success",
        parameters: [
          "data_length": data.count
        ])
      return data
    } catch {
      analytics.logEvent(
        "fetch_local_data_failed",
        parameters: [
          "error": error.localizedDescription
        ])
      throw error
    }
  }

  func fetchRemoteData() async throws -> String {
    analytics.logEvent("fetch_remote_data_started", parameters: nil)

    do {
      let data = try await moreRepository.fetchData(fromCache: false)
      analytics.logEvent(
        "fetch_remote_data_success",
        parameters: [
          "data_length": data.count
        ])
      return data
    } catch {
      analytics.logEvent(
        "fetch_remote_data_failed",
        parameters: [
          "error": error.localizedDescription
        ])
      throw error
    }
  }
}
