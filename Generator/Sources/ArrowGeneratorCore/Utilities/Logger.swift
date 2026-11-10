protocol Logging {
  func log(_ message: String)
  func warn(_ message: String)
}

class Logger: Logging {
  let isVerbose: Bool

  init(isVerbose: Bool) {
    self.isVerbose = isVerbose
  }

  func log(_ message: String) {
    if isVerbose {
      print(message)
    }
  }

  /// Always printed, in the `warning:` form Xcode shows in the build log.
  func warn(_ message: String) {
    print("warning: \(message)")
  }
}
