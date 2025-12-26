import SwiftUI
import Arrow

final class HomeFactory {
  @Inject var viewModel: HomeViewModel

  func makeHomeView() -> HomeView {
    return HomeView(viewModel: viewModel)
  }
}
