import SwiftUI
import Arrow
import Analytics

final class HomeModule: TransientScope {
  func provideViewModel(analytics: Analytics) -> HomeViewModel {
    HomeViewModel(analytics: analytics)
  }
}
