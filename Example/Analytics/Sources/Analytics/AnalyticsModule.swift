import Arrow

public struct AnalyticsModule: SingletonScope {
  public init() {}

  public func provideFirebaseProvider() -> FirebaseAnalyticsProvider {
    FirebaseAnalyticsProvider()
  }

  public func provideSnowplowProvider() -> SnowplowAnalyticsProvider {
    SnowplowAnalyticsProvider(
      endpoint: "https://collector.snowplowanalytics.com",
      namespace: "example-app",
      appId: "com.example.app",
    )
  }

  public func provideAnalytics(
    _ firebaseProvider: FirebaseAnalyticsProvider,
    _ snowplowProvider: SnowplowAnalyticsProvider,
  ) -> Analytics {
    let providers: [AnalyticsProvider] = [
      firebaseProvider,
      snowplowProvider,
    ]

    return AnalyticsImpl(providers: providers)
  }
}
