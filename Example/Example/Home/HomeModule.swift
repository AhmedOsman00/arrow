import SwiftUI
import Arrow
import ArrowMacros
import Analytics

final class HomeModule: TransientScope {
    func provideViewModel(analytics: Analytics) -> HomeViewModel {
        HomeViewModel(analytics: analytics)
    }
}
