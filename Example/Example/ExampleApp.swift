import Analytics
import Arrow
import Core
import SwiftUI

@main
struct ExampleApp: App {
  init() {
    // Registries come from each dependencies.generated.swift; register dependencies before dependents.
    Container.shared.register(
      CoreDependencies.self,
      AnalyticsDependencies.self,
      ExampleDependencies.self
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
