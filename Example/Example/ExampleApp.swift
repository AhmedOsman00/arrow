import SwiftUI
import Arrow

let container = Container.shared

@main
struct ExampleApp: App {
  init() {
    container.register()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
