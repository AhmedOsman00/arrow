import Arrow

struct CoreModule: SingletonScope {
  var provideNetwork: Networking {
    NetworkingImpl()
  }
}

extension CoreModule: TransientScope {
  func provideConsoleLogger() -> LoggerFactory {
    { prefix in
      ConsoleLogger(prefix: prefix)
    }
  }
}
