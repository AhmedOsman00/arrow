protocol Logging {
    func log(_ message: String)
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
}
