import Foundation

public final class FirebaseAnalyticsProvider: AnalyticsProvider {
    public let name = "Firebase"
    
    public init() {
        print("[Firebase] Analytics provider initialized")
    }

    public func logEvent(_ event: String, parameters: [String: Any]?) {
        print("[Firebase] Event: \(event)")
        if let parameters = parameters {
            print("[Firebase] Parameters: \(parameters)")
        }
    }
}
