import SwiftUI

struct MoreViewControllerWrapper: UIViewControllerRepresentable {
    let factory: MoreFactory

    func makeUIViewController(context: Context) -> MoreViewController {
        factory.makeMoreViewController()
    }

    func updateUIViewController(_ uiViewController: MoreViewController, context: Context) {
        // No updates needed
    }
}
