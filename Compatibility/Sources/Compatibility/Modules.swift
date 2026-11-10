import Arrow
import Foundation

// One of each provider shape the generator supports, so the generated registry uses every kind of
// registration Arrow offers.

final class Clock {}

final class Database {
  let clock: Clock

  init(clock: Clock) {
    self.clock = clock
  }
}

protocol Greeter {
  func greet() -> String
}

struct PlainGreeter: Greeter {
  let greeting: String

  func greet() -> String { greeting }
}

/// Not provided by any module, so optional parameters of this type resolve to `nil`.
final class Cache {}

enum Mode {
  case debug
  case release
}

final class Service {
  let greeter: any Greeter
  let formalGreeter: any Greeter
  let database: Database
  let cache: Cache?
  let prefix: String

  init(greeter: any Greeter, formalGreeter: any Greeter, database: Database, cache: Cache?, prefix: String) {
    self.greeter = greeter
    self.formalGreeter = formalGreeter
    self.database = database
    self.cache = cache
    self.prefix = prefix
  }
}

@MainActor
final class Screen {
  let service: Service

  init(service: Service) {
    self.service = service
  }
}

final class CoreModule: SingletonScope {
  var clock: Clock {
    Clock()
  }

  var greeter: any Greeter {
    PlainGreeter(greeting: "Hello")
  }

  /// A doc-comment marker names the provider without the `ArrowMacros` product.
  /// @Name("formal")
  var formalGreeter: any Greeter {
    PlainGreeter(greeting: "Good day")
  }

  #if DEBUG
    var mode: Mode { .debug }
  #else
    var mode: Mode { .release }
  #endif
}

final class StorageModule: LazySingletonScope {
  func database(clock: Clock) -> Database {
    Database(clock: clock)
  }
}

final class ServiceModule: TransientScope {
  func service(
    greeter: any Greeter,
    @Named("formal") formalGreeter: any Greeter,
    database: Database,
    cache: Cache?,
    prefix: String = ">"
  ) -> Service {
    Service(greeter: greeter, formalGreeter: formalGreeter, database: database, cache: cache, prefix: prefix)
  }
}

@MainActor
final class ScreenModule: TransientScope {
  nonisolated init() {}

  func screen(service: Service) -> Screen {
    Screen(service: service)
  }
}
