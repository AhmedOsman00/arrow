protocol MoreCoordinatorProtocol {
    func navigate(to destination: String)
}

final class MoreCoordinator: MoreCoordinatorProtocol {
    let root: String

    init(root: String) {
        self.root = root
    }

    func navigate(to destination: String) {
        print("Navigating to: \(destination)")
    }
}
