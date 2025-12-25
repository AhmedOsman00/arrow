import Foundation

public protocol Analytics {
    func logEvent(_ event: String, parameters: [String: Any]?)
}

public final class AnalyticsImpl: Analytics {
    private var providers: [AnalyticsProvider] = []
    
    public init(providers: [AnalyticsProvider] = []) {
        self.providers = providers
        print("[Analytics] Initialized with \(providers.count) provider(s)")
        providers.forEach { provider in
            print("[Analytics] - \(provider.name)")
        }
    }
    
    public func logEvent(_ event: String, parameters: [String: Any]? = nil) {
        print("[Analytics] Broadcasting event '\(event)' to \(providers.count) provider(s)")
        providers.forEach { provider in
            provider.logEvent(event, parameters: parameters)
        }
    }
}
