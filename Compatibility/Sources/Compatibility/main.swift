import Arrow
import Foundation

// Registers the generated registry and checks what each provider resolves to, so a registration
// that compiles but is wired wrongly also fails.

func check(_ condition: Bool, _ message: String) {
  guard condition else {
    print("❌ \(message)")
    exit(1)
  }
  print("✅ \(message)")
}

let container = Container.shared
container.register(CompatibilityDependencies.self)

let clock = container.resolve(Clock.self)
check(container.resolve(Clock.self) === clock, "Singleton returns the same instance")

let database = container.resolve(Database.self)
check(container.resolve(Database.self) === database, "Lazy singleton returns the same instance")
check(database.clock === clock, "Lazy singleton gets its dependency")

let service = container.resolve(Service.self)
check(container.resolve(Service.self) !== service, "Transient returns a new instance")
check(service.greeter.greet() == "Hello", "Unnamed existential resolves")
check(service.formalGreeter.greet() == "Good day", "@Named parameter gets the doc-comment-named provider")
check(container.resolve((any Greeter).self, name: "formal").greet() == "Good day", "Named provider resolves by name")
check(service.cache == nil, "Optional parameter with no provider is nil")
check(service.prefix == ">", "Default parameter keeps its default")

let screen = container.resolve(Screen.self)
check(screen.service.greeter.greet() == "Hello", "@MainActor module resolves on the main thread")

#if DEBUG
  check(container.resolve(Mode.self) == .debug, "#if DEBUG branch is registered")
#else
  check(container.resolve(Mode.self) == .release, "#else branch is registered")
#endif
