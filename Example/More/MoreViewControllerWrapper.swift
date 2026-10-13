import Arrow
import SwiftUI

struct MoreViewControllerWrapper: UIViewControllerRepresentable {
  @ViewModel var viewModel: MoreViewModel

  func makeUIViewController(context: Context) -> MoreViewController {
    let coordinator = MoreCoordinator(root: "More")
    return MoreViewController(viewModel: viewModel, coordinator: coordinator)
  }

  func updateUIViewController(_ uiViewController: MoreViewController, context: Context) {
    // No updates needed
  }
}
