import Foundation
import Testing
@testable import Arrow

private final class First {}
private final class Second {}

/// Each cycle crashes the process, so these run as exit tests and check the message it printed.
struct CircularDependencyTests {
  @Test
  func transientCycleCrashesWithItsPath() async {
    let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
      let container = Container()
      container.register(First.self) { resolver in
        _ = resolver.resolve(Second.self)
        return First()
      }
      container.register(Second.self) { resolver in
        _ = resolver.resolve(First.self)
        return Second()
      }
      _ = container.resolve(First.self)
    }

    #expect(errorOutput(result).contains("Circular dependency: 'First' -> 'Second' -> 'First'"))
  }

  @Test
  func namedTransientCycleNamesTheDependency() async {
    let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
      let container = Container()
      container.register(First.self, name: "loop") { resolver in
        resolver.resolve(First.self, name: "loop")
      }
      _ = container.resolve(First.self, name: "loop")
    }

    let cycle = "'First' named \"loop\" -> 'First' named \"loop\""
    #expect(errorOutput(result).contains("Circular dependency: \(cycle)"))
  }

  @Test
  func lazySingletonCycleAcrossThreadsCrashesInsteadOfDeadlocking() async {
    let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
      let container = Container()
      // Both threads start creating before either asks for the other, so each holds one lock.
      let bothCreating = DispatchGroup()
      bothCreating.enter()
      bothCreating.enter()
      container.register(First.self, objectScope: .lazySingleton) { resolver in
        bothCreating.leave()
        bothCreating.wait()
        _ = resolver.resolve(Second.self)
        return First()
      }
      container.register(Second.self, objectScope: .lazySingleton) { resolver in
        bothCreating.leave()
        bothCreating.wait()
        _ = resolver.resolve(First.self)
        return Second()
      }
      DispatchQueue.global().async { _ = container.resolve(First.self) }
      DispatchQueue.global().async { _ = container.resolve(Second.self) }
      // If the threads deadlock instead, exit cleanly so the test fails rather than hangs.
      Thread.sleep(forTimeInterval: 5)
      exit(0)
    }

    // Whichever thread waits last detects the cycle, so it can start from either singleton.
    let message = "Circular dependency between lazy singletons resolved on different threads: "
    let cycles = ["'First' -> 'Second' -> 'First'", "'Second' -> 'First' -> 'Second'"]
    #expect(cycles.contains { errorOutput(result).contains(message + $0) })
  }

  @Test
  func lazySingletonSharedAcrossThreadsWithoutCycleResolves() {
    let container = Container()
    container.register(Second.self, objectScope: .lazySingleton) { _ in
      Thread.sleep(forTimeInterval: 0.01)
      return Second()
    }
    container.register(First.self, objectScope: .lazySingleton) { resolver in
      _ = resolver.resolve(Second.self)
      return First()
    }

    DispatchQueue.concurrentPerform(iterations: 50) { index in
      if index.isMultiple(of: 2) {
        _ = container.resolve(First.self)
      } else {
        _ = container.resolve(Second.self)
      }
    }

    #expect(container.tryResolve(First.self) != nil)
  }
}

private func errorOutput(_ result: ExitTest.Result?) -> String {
  result.flatMap { String(bytes: $0.standardErrorContent, encoding: .utf8) } ?? ""
}
