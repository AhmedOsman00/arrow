import Foundation
import Combine
import Analytics

@Observable
final class HomeViewModel {
  var counter: Int = 0
  var greeting: String = "Welcome to Home!"

  private let analytics: Analytics

  init(analytics: Analytics) {
    self.analytics = analytics
    analytics.logEvent("home_viewmodel_initialized", parameters: nil)
  }

  func incrementCounter() {
    counter += 1
    analytics.logEvent(
      "counter_incremented",
      parameters: [
        "new_value": counter
      ])
  }

  func updateGreeting(_ text: String) {
    greeting = text
    analytics.logEvent(
      "greeting_updated",
      parameters: [
        "length": text.count
      ])
  }

  func resetCounter() {
    let oldValue = counter
    counter = 0
    analytics.logEvent(
      "counter_reset",
      parameters: [
        "previous_value": oldValue
      ])
  }
}
