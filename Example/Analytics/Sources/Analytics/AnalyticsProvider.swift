import Foundation

public protocol AnalyticsProvider {
    var name: String { get }

    func logEvent(_ event: String, parameters: [String: Any]?)
}
