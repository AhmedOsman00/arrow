import Arrow

struct AnalyticsModule: SingletonScope {

  func provideFirebaseProvider() -> FirebaseAnalyticsProvider {
    FirebaseAnalyticsProvider()
  }

  func provideSnowplowProvider() -> SnowplowAnalyticsProvider {
    SnowplowAnalyticsProvider(
      endpoint: "https://collector.snowplowanalytics.com",
      namespace: "example-app",
      appId: "com.example.app",
    )
  }

  func provideAnalytics(
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
