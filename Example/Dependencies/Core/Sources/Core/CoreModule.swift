import Arrow

public struct CoreModule: SingletonScope {
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
