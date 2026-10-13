import SwiftUI
import Arrow

struct ContentView: View {
  var body: some View {
    TabView {
      HomeFactory()
        .makeHomeView()
        .tabItem {
          Label("Home", systemImage: "house.fill")
        }

      MoreViewControllerWrapper()
        .tabItem {
          Label("More", systemImage: "ellipsis.circle.fill")
        }
    }
  }
}
