import Arrow

/// Networking is a lazy singleton: created on first use rather than at app launch.
public struct CoreModule: LazySingletonScope {
  public init() {}

  public var provideNetwork: Networking {
    NetworkingImpl()
  }
}

extension CoreModule: TransientScope {
  public func provideConsoleLogger() -> LoggerFactory {
    { prefix in
      ConsoleLogger(prefix: prefix)
    }
  }
}
