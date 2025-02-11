import XCTest
@testable import Script

class DependencyResolverTests: XCTestCase {
    
    func testValidDependencyGraph() throws {
        let module = createDependencyModule(
            types: [
                createDependency(type: "A", dependencies: ["B"]),
                createDependency(type: "B", dependencies: ["C"]),
                createDependency(type: "C", dependencies: [])
            ]
        )

        let resolver = DependencyResolver(data: [module])

        // Resolve dependency order
        let order = try resolver.resolve()
        XCTAssertEqual(order, ["C", "B", "A"])
    }

    func testMissingDependencies() throws {
        let module = createDependencyModule(
            types: [
                createDependency(type: "A", dependencies: ["B"]),
                createDependency(type: "B", dependencies: ["C", "E"]), // E is missing
                createDependency(type: "C", dependencies: ["D"]) // D is missing
            ]
        )

        let resolver = DependencyResolver(data: [module])

        // Check for missing dependencies
        XCTAssertThrowsError(try resolver.validate()) { error in
            guard case let DependencyResolver.DependencyError.missingDependencies(missing) = error else {
                return XCTFail("Expected missing dependencies error")
            }
            XCTAssertEqual(Set(missing), Set(["E", "D"]))
        }
    }

    func testDuplicateDependencies() throws {
        let module = createDependencyModule(
            types: [
                createDependency(type: "A", dependencies: ["B"]),
                createDependency(type: "B", dependencies: []),
                createDependency(type: "C", dependencies: []),
                createDependency(type: "A", dependencies: ["C"]) // Duplicate A
            ]
        )

        let resolver = DependencyResolver(data: [module])

        // Check for duplicate dependencies
        XCTAssertThrowsError(try resolver.validate()) { error in
            guard case DependencyResolver.DependencyError.duplicateDependencies(let duplicates) = error else {
                return XCTFail("Expected duplicate dependencies error")
            }
            XCTAssertEqual(duplicates, ["_:A"])
        }
    }
    
    func testCircularDependencies() throws {
        let module = createDependencyModule(
            types: [
                createDependency(type: "A", dependencies: ["B"]),
                createDependency(type: "B", dependencies: ["C"]),
                createDependency(type: "C", dependencies: ["A"]) // Circular dependency
            ]
        )

        let resolver = DependencyResolver(data: [module])

        // Check for circular dependencies
        XCTAssertThrowsError(try resolver.resolve()) { error in
            guard case DependencyResolver.DependencyError.circularDependency = error else {
                return XCTFail("Expected circular dependency error")
            }
        }
    }

    func testEmptyGraph() throws {
        let resolver = DependencyResolver(data: [])

        // Resolve dependency order
        let order = try resolver.resolve()
        XCTAssertTrue(order.isEmpty)
    }
}

private extension DependencyResolverTests {
    func createDependencyModule(name: String = "Module",
                                type: DependencyModule.ModuleType = .struct,
                                scope: DependencyModule.Scope = .transient,
                                imports: Set<String> = ["Framework"],
                                types: Set<Dependency>) -> DependencyModule {
        return DependencyModule(type: type, imports: imports, name: name, scope: scope, types: types)
    }

    func createDependency(type: String,
                          dependencies: [String],
                          name: String? = nil,
                          block: String = "block") -> Dependency {
        return Dependency(dependencyType: .method,
                          name: name,
                          type: type,
                          block: block,
                          parameters: dependencies.map { .init(type: $0, name: nil, value: nil) })
    }
}
