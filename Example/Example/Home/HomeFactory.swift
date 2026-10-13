import SwiftUI
import Arrow

struct HomeFactory {
  @Inject var viewModel: HomeViewModel

  func makeHomeView() -> HomeView {
    return HomeView(viewModel: viewModel)
  }
}
