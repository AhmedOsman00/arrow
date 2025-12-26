import SwiftUI
import Arrow

@main
struct ExampleApp: App {
  init() {
    Container.shared.register()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
