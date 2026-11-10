import SwiftParser
import XCTest

@testable import ArrowGeneratorCore

class DependencyResolverTests: XCTestCase {
  func testValidDependencyGraph() throws {
    let module: DependencyModule = .fixture(
      types: [
        .fixture(type: "A", dependencies: ["B": nil]),
        .fixture(type: "B", dependencies: ["C": nil]),
        .fixture(type: "C", dependencies: [:]),
      ]
    )

    let resolver = DependencyGraphResolver(data: [module])

    // Resolve dependency order
    let order = try resolver.resolve()
    XCTAssertEqual(order, [.init("_:C"), .init("_:B"), .init("_:A")])
  }

  func testValidDependencyGraphx() throws {
    let module: DependencyModule = .fixture(
      types: [
        .fixture(type: "A", dependencies: ["B": "x"]),
        .fixture(type: "B", name: "x", dependencies: ["C": "y"]),
        .fixture(type: "C", name: "y", dependencies: [:]),
      ]
    )

    let resolver = DependencyGraphResolver(data: [module])

    // Resolve dependency order
    let order = try resolver.resolve()
    XCTAssertEqual(order, [.init("y:C"), .init("x:B"), .init("_:A")])
  }

  func testValidDependencyGraph_withMoreThanModule() throws {
    let module1: DependencyModule = .fixture(
      types: [
        .fixture(type: "A", dependencies: ["B": nil]),
        .fixture(type: "B", dependencies: ["C": nil]),
        .fixture(type: "C", dependencies: ["D": nil]),
      ]
    )

    let module2: DependencyModule = .fixture(
      types: [
        .fixture(type: "D")
      ]
    )

    let resolver = DependencyGraphResolver(data: [module1, module2])

    // Resolve dependency order
    let order = try resolver.resolve()
    XCTAssertEqual(order, [.init("_:D"), .init("_:C"), .init("_:B"), .init("_:A")])
  }

  func testMissingDependencies() throws {
    let module: DependencyModule = .fixture(
      types: [
        .fixture(type: "A", dependencies: ["B": nil]),
        .fixture(type: "B", dependencies: ["C": nil, "E": nil]),  // E is missing
        .fixture(type: "C", dependencies: ["D": nil]),  // D is missing
      ]
    )

    let resolver = DependencyGraphResolver(data: [module])

    // Check for missing dependencies
    XCTAssertThrowsError(try resolver.validate()) { error in
      guard case DependencyGraphResolver.DependencyError.missingDependencies(let missing) = error
      else {
        return XCTFail("Expected missing dependencies error")
      }
      XCTAssertEqual(Set(missing), Set(["_:E", "_:D"]))
    }
  }

  func testDuplicateDependencies() throws {
    let module: DependencyModule = .fixture(
      types: [
        .fixture(type: "A", dependencies: ["B": nil]),
        .fixture(type: "B", dependencies: [:]),
        .fixture(type: "C", dependencies: [:]),
        .fixture(type: "A", dependencies: ["C": nil]),  // Duplicate A
      ]
    )

    let resolver = DependencyGraphResolver(data: [module])

    // Check for duplicate dependencies
    XCTAssertThrowsError(try resolver.validate()) { error in
      guard
        case DependencyGraphResolver.DependencyError.duplicateDependencies(let duplicates) = error
      else {
        return XCTFail("Expected duplicate dependencies error")
      }
      XCTAssertEqual(duplicates, ["_:A"])
    }
  }

  func testCircularDependencies() throws {
    let module: DependencyModule = .fixture(
      types: [
        .fixture(type: "A", dependencies: ["B": nil]),
        .fixture(type: "B", dependencies: ["C": nil]),
        .fixture(type: "C", dependencies: ["A": nil]),  // Circular dependency
      ]
    )

    let resolver = DependencyGraphResolver(data: [module])

    // Check for circular dependencies
    XCTAssertThrowsError(try resolver.resolve()) { error in
      guard case DependencyGraphResolver.DependencyError.circularDependency(let cycle) = error else {
        return XCTFail("Expected circular dependency error")
      }
      XCTAssertEqual(cycle, ["_:A", "_:B", "_:C", "_:A"])
    }
  }

  func testResolve_independentNodes_areSortedDeterministically() throws {
    let module: DependencyModule = .fixture(
      types: [
        .fixture(type: "C"),
        .fixture(type: "A"),
        .fixture(type: "B"),
      ]
    )

    let order = try DependencyGraphResolver(data: [module]).resolve()

    XCTAssertEqual(order, [.init("_:A"), .init("_:B"), .init("_:C")])
  }

  func testEmptyGraph() throws {
    let resolver = DependencyGraphResolver(data: [])

    // Resolve dependency order
    let order = try resolver.resolve()
    XCTAssertTrue(order.isEmpty)
  }

  func testNameMatchingTypeName_isDuplicateOfUnnamed() throws {
    // The container keys an unnamed `Service` by its type name, so these two would collide at runtime.
    let module: DependencyModule = .fixture(
      types: [
        .fixture(type: "Service", block: "a"),
        .fixture(type: "Service", name: "Service", block: "b"),
      ])

    XCTAssertThrowsError(try DependencyGraphResolver(data: [module]).validate())
  }

  func testEquivalentTypeSpellings_resolveToSameDependency() throws {
    let module: DependencyModule = .fixture(
      types: [
        .fixture(type: "A", dependencies: ["Array<String>": nil, "Optional<B>": nil, "[String : Int]": nil]),
        .fixture(type: "[String]", block: "strings"),
        .fixture(type: "B?", block: "b"),
        .fixture(type: "Dictionary<String, Int>", block: "dictionary"),
      ])

    XCTAssertNoThrow(try DependencyGraphResolver(data: [module]).resolveAndValidate())
  }

  func testDuplicatesInExclusiveIfBranches_areAllowed() throws {
    let modules = try parseModules(
      """
      final class Module: TransientScope {
          #if DEBUG
          var logger: Logger { ConsoleLogger() }
          #else
          var logger: Logger { NoopLogger() }
          #endif
      }
      """)

    XCTAssertEqual(try DependencyGraphResolver(data: modules).resolveAndValidate(), [.init("_:Logger")])
  }

  func testDuplicatesInIndependentIfBlocks_areRejected() throws {
    let modules = try parseModules(
      """
      final class Module: TransientScope {
          #if DEBUG
          func debugLogger() -> Logger { ConsoleLogger() }
          #endif
          #if BETA
          func betaLogger() -> Logger { BetaLogger() }
          #endif
      }
      """)

    XCTAssertThrowsError(try DependencyGraphResolver(data: modules).validate())
  }

  private func parseModules(_ source: String) throws -> [DependencyModule] {
    try Array(DependencyModulesParser(viewMode: .all).parse(Parser.parse(source: source)))
  }
}

extension DependencyModule {
  static func fixture(
    name: String = "Module",
    type: DependencyModule.ModuleType = .struct,
    scope: DependencyModule.Scope = .transient,
    imports: Set<String> = ["Framework"],
    types: Set<Dependency>
  ) -> DependencyModule {
    return DependencyModule(type: type, imports: imports, name: name, scope: scope, types: types)
  }
}

extension Dependency {
  static func fixture(
    type: String,
    name: String? = nil,
    block: String = "block",
    parameters: [Parameter] = [],
    dependencies: [String: String?] = [:]
  ) -> Dependency {
    let mergedParameters =
      parameters
      + dependencies.map {
        Dependency.Parameter(type: $0, name: nil, value: nil, dependencyId: $1)
      }
    return Dependency(
      dependencyType: .method,
      name: name,
      type: type,
      block: block,
      parameters: mergedParameters)
  }
}

// MARK: - Optional parameters and captive dependencies

extension DependencyResolverTests {
  func testOptionalParameter_isNotMissingWhenWrappedTypeIsAbsent() throws {
    let module = DependencyModule.fixture(types: [.fixture(type: "Service", dependencies: ["Cache?": nil])])

    XCTAssertEqual(try DependencyGraphResolver(data: [module]).resolveAndValidate(), [.init("_:Service")])
  }

  func testOptionalParameter_isOrderedAfterWrappedType() throws {
    let module = DependencyModule.fixture(types: [
      .fixture(type: "Service", dependencies: ["Optional<Cache>": "main"]),
      .fixture(type: "Cache", name: "main"),
    ])

    XCTAssertEqual(
      try DependencyGraphResolver(data: [module]).resolveAndValidate(), [.init("main:Cache"), .init("_:Service")])
  }

  func testCaptiveDependencyWarnings_flagSingletonsDependingOnTransients() {
    let transient = DependencyModule.fixture(
      name: "Transient", scope: .transient, types: [.fixture(type: "Formatter")])
    let singleton = DependencyModule.fixture(
      name: "Singleton", scope: .singleton,
      types: [
        .fixture(type: "Service", block: "service", dependencies: ["Formatter": nil]),
        .fixture(type: "Clock", block: "clock"),
      ])
    let lazy = DependencyModule.fixture(
      name: "Lazy", scope: .lazySingleton,
      types: [.fixture(type: "Report", block: "report", dependencies: ["Formatter?": nil, "Clock": nil])])
    let resolver = DependencyGraphResolver(data: [transient, singleton, lazy])

    XCTAssertEqual(
      resolver.captiveDependencyWarnings(in: [transient, singleton, lazy]),
      [
        "`Singleton.service` is a singleton but depends on transient `Formatter`, so it keeps one instance of it forever.",
        "`Lazy.report` is a lazySingleton but depends on transient `Formatter`, so it keeps one instance of it forever.",
      ])
    XCTAssertEqual(resolver.captiveDependencyWarnings(in: [transient]), [])
  }
}

final class TypeNameTests: XCTestCase {
  func testOptionalWrapped() {
    XCTAssertEqual(TypeName.optionalWrapped("Cache?"), "Cache")
    XCTAssertEqual(TypeName.optionalWrapped("Cache!"), "Cache")
    XCTAssertEqual(TypeName.optionalWrapped("Optional<[String]>"), "[String]")
    XCTAssertEqual(TypeName.optionalWrapped("(any Cache)?"), "any Cache")
    XCTAssertEqual(TypeName.optionalWrapped("Cache??"), "Cache?")
    XCTAssertNil(TypeName.optionalWrapped("Cache"))
    XCTAssertNil(TypeName.optionalWrapped("[Cache?]"))
  }
}
