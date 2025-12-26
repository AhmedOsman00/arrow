import XCTest
@testable import Arrow

// Test helpers
protocol TestService {
  var id: String { get }
}

final class TestServiceImpl: TestService {
  let id: String
  init(id: String = "default") {
    self.id = id
  }
}

final class TestCounter {
  nonisolated(unsafe) static var creationCount = 0

  init() {
    TestCounter.creationCount += 1
  }

  static func reset() {
    creationCount = 0
  }
}

final class ContainerTests: XCTestCase {
  override func setUp() {
    super.setUp()
    Container.shared.reset()
    TestCounter.reset()
  }

  override func tearDown() {
    Container.shared.reset()
    TestCounter.reset()
    super.tearDown()
  }

  // MARK: - Registration Tests

  func testRegisterAndResolveSimpleDependency() {
    // Given
    let expectedId = "test-service"
    Container.shared.register(TestService.self) { _ in
      TestServiceImpl(id: expectedId)
    }

    // When
    let resolved: TestService = Container.shared.resolve(TestService.self)

    // Then
    XCTAssertEqual(resolved.id, expectedId)
  }

  // MARK: - Scope Tests

  func testSingletonScopeCreatesOnlyOneInstance() {
    // Given
    Container.shared.register(TestCounter.self, objectScope: .singleton) { _ in
      TestCounter()
    }

    // When
    let first: TestCounter = Container.shared.resolve(TestCounter.self)
    let second: TestCounter = Container.shared.resolved()

    // Then
    XCTAssertTrue(first === second, "Singleton should return the same instance")
    XCTAssertEqual(TestCounter.creationCount, 1, "Singleton should be created only once")
  }

  func testTransientScopeCreatesNewInstanceEachTime() {
    // Given
    Container.shared.register(TestCounter.self, objectScope: .transient) { _ in
      TestCounter()
    }

    // When
    let first: TestCounter = Container.shared.resolve(TestCounter.self)
    let second: TestCounter = Container.shared.resolve(TestCounter.self)

    // Then
    XCTAssertFalse(first === second, "Transient should return different instances")
    XCTAssertEqual(TestCounter.creationCount, 2, "Transient should be created each time")
  }

  // MARK: - Named Dependencies Tests

  func testNamedDependenciesAreResolvedSeparately() {
    // Given
    Container.shared.register(TestService.self, name: "primary") { _ in
      TestServiceImpl(id: "primary")
    }
    Container.shared.register(TestService.self, name: "secondary") { _ in
      TestServiceImpl(id: "secondary")
    }

    // When
    let primary: TestService = Container.shared.resolve(TestService.self, name: "primary")
    let secondary: TestService = Container.shared.resolve(TestService.self, name: "secondary")

    // Then
    XCTAssertEqual(primary.id, "primary")
    XCTAssertEqual(secondary.id, "secondary")
  }

  // MARK: - Error Handling Tests
  func testTryResolveReturnsNilForMissingDependency() {
    // When
    let resolved: TestService? = Container.shared.tryResolve(TestService.self)

    // Then
    XCTAssertNil(resolved)
  }

  func testTryResolveReturnsValueForRegisteredDependency() {
    // Given
    Container.shared.register(TestService.self) { _ in
      TestServiceImpl(id: "test")
    }

    // When
    let resolved: TestService? = Container.shared.tryResolve(TestService.self)

    // Then
    XCTAssertNotNil(resolved)
    XCTAssertEqual(resolved?.id, "test")
  }

  // MARK: - Unregister Tests

  func testUnregisterRemovesDependency() {
    // Given
    Container.shared.register(TestService.self) { _ in
      TestServiceImpl(id: "test")
    }

    // When
    Container.shared.unregister(TestService.self)

    // Then
    let resolved: TestService? = Container.shared.tryResolve(TestService.self)
    XCTAssertNil(resolved)
  }

  func testUnregisterNamedDependency() {
    // Given
    Container.shared.register(TestService.self, name: "primary") { _ in
      TestServiceImpl(id: "primary")
    }
    Container.shared.register(TestService.self, name: "secondary") { _ in
      TestServiceImpl(id: "secondary")
    }

    // When
    Container.shared.unregister(TestService.self, name: "primary")

    // Then
    let primary: TestService? = Container.shared.tryResolve(TestService.self, name: "primary")
    let secondary: TestService? = Container.shared.tryResolve(TestService.self, name: "secondary")

    XCTAssertNil(primary)
    XCTAssertNotNil(secondary)
  }

  func testResetRemovesAllDependencies() {
    // Given
    Container.shared.register(TestService.self, name: "first") { _ in
      TestServiceImpl(id: "first")
    }
    Container.shared.register(TestService.self, name: "second") { _ in
      TestServiceImpl(id: "second")
    }

    // When
    Container.shared.reset()

    // Then
    let first: TestService? = Container.shared.tryResolve(TestService.self, name: "first")
    let second: TestService? = Container.shared.tryResolve(TestService.self, name: "second")

    XCTAssertNil(first)
    XCTAssertNil(second)
  }

  // MARK: - Property Wrapper Tests

  func testInjectPropertyWrapperResolvesCorrectly() {
    // Given
    Container.shared.register(TestService.self) { _ in
      TestServiceImpl(id: "injected")
    }

    // When
    class TestClass {
      @Inject var service: TestService
    }
    let instance = TestClass()

    // Then
    XCTAssertEqual(instance.service.id, "injected")
  }

  func testInjectPropertyWrapperCachesValue() {
    // Given
    Container.shared.register(TestCounter.self, objectScope: .transient) { _ in
      TestCounter()
    }

    // When
    class TestClass {
      @Inject var counter: TestCounter
    }
    let instance = TestClass()
    let first = instance.counter
    let second = instance.counter

    // Then
    XCTAssertTrue(first === second, "Property wrapper should cache the value")
    XCTAssertEqual(TestCounter.creationCount, 1, "Should only resolve once")
  }

  func testAutowirePropertyWrapperReturnsNilForMissingDependency() {
    // When
    class TestClass {
      @Autowire var service: TestService?
    }
    let instance = TestClass()

    // Then
    XCTAssertNil(instance.service)
  }

  func testAutowirePropertyWrapperResolvesRegisteredDependency() {
    // Given
    Container.shared.register(TestService.self) { _ in
      TestServiceImpl(id: "autowired")
    }

    // When
    class TestClass {
      @Autowire var service: TestService?
    }
    let instance = TestClass()

    // Then
    XCTAssertNotNil(instance.service)
    XCTAssertEqual(instance.service?.id, "autowired")
  }

  func testAutowirePropertyWrapperCachesNil() {
    // When
    class TestClass {
      @Autowire var counter: TestCounter?
    }
    let instance = TestClass()

    // Access multiple times
    let first = instance.counter
    let second = instance.counter

    // Then
    XCTAssertNil(first)
    XCTAssertNil(second)
    XCTAssertEqual(TestCounter.creationCount, 0, "Should not create any instances")
  }

  func testNamedInjectPropertyWrapper() {
    // Given
    Container.shared.register(TestService.self, name: "custom") { _ in
      TestServiceImpl(id: "custom-service")
    }

    // When
    class TestClass {
      @Inject(name: "custom")
      var service: TestService
    }
    let instance = TestClass()

    // Then
    XCTAssertEqual(instance.service.id, "custom-service")
  }
}
