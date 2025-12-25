public protocol Logger {
    func log(_ message: String)
}

public typealias LoggerFactory = (_ prefix: String) -> Logger

final class ConsoleLogger: Logger {
    let prefix: String

    init(prefix: String) {
        self.prefix = prefix
    }

    func log(_ message: String) {
        print("\(prefix) \(message)")
    }
}
