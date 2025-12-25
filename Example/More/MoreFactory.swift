import UIKit
import Arrow

final class MoreFactory {
    @Inject var viewModel: MoreViewModel

    func makeMoreViewController() -> MoreViewController {
        let coordinator = MoreCoordinator(root: "More")
        return MoreViewController(viewModel: viewModel, coordinator: coordinator)
    }
}
