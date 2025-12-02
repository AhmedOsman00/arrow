import XCTest
@testable import ArrowGeneratorCore

class DependencyResolverTests: XCTestCase {
    
    func testValidDependencyGraph() throws {
        let module: DependencyModule = .fixture(
            types: [
                .fixture(type: "A", dependencies: ["B": nil]),
                .fixture(type: "B", dependencies: ["C": nil]),
                .fixture(type: "C", dependencies: [:])
            ]
        )
        
        let resolver = DependencyGraphResolver(data: [module])
        
        // Resolve dependency order
        let order = try resolver.resolve()
        XCTAssertEqual(order, ["_:C", "_:B", "_:A"])
    }
    
    func testValidDependencyGraphx() throws {
        let module: DependencyModule = .fixture(
            types: [
                .fixture(type: "A", dependencies: ["B": "x"]),
                .fixture(type: "B", name: "x", dependencies: ["C": "y"]),
                .fixture(type: "C", name: "y", dependencies: [:])
            ]
        )
        
        let resolver = DependencyGraphResolver(data: [module])
        
        // Resolve dependency order
        let order = try resolver.resolve()
        XCTAssertEqual(order, ["y:C", "x:B", "_:A"])
    }
    
    func testValidDependencyGraph_withMoreThanModule() throws {
        let module1: DependencyModule = .fixture(
            types: [
                .fixture(type: "A", dependencies: ["B": nil]),
                .fixture(type: "B", dependencies: ["C": nil]),
                .fixture(type: "C", dependencies: ["D": nil])
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
        XCTAssertEqual(order, ["_:D", "_:C", "_:B", "_:A"])
    }
    
    func testMissingDependencies() throws {
        let module: DependencyModule = .fixture(
            types: [
                .fixture(type: "A", dependencies: ["B": nil]),
                .fixture(type: "B", dependencies: ["C": nil, "E": nil]), // E is missing
                .fixture(type: "C", dependencies: ["D": nil]) // D is missing
            ]
        )
        
        let resolver = DependencyGraphResolver(data: [module])
        
        // Check for missing dependencies
        XCTAssertThrowsError(try resolver.validate()) { error in
            guard case let DependencyGraphResolver.DependencyError.missingDependencies(missing) = error else {
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
                .fixture(type: "A", dependencies: ["C": nil]) // Duplicate A
            ]
        )
        
        let resolver = DependencyGraphResolver(data: [module])
        
        // Check for duplicate dependencies
        XCTAssertThrowsError(try resolver.validate()) { error in
            guard case DependencyGraphResolver.DependencyError.duplicateDependencies(let duplicates) = error else {
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
                .fixture(type: "C", dependencies: ["A": nil]) // Circular dependency
            ]
        )
        
        let resolver = DependencyGraphResolver(data: [module])
        
        // Check for circular dependencies
        XCTAssertThrowsError(try resolver.resolve()) { error in
            guard case DependencyGraphResolver.DependencyError.circularDependency = error else {
                return XCTFail("Expected circular dependency error")
            }
        }
    }
    
    func testEmptyGraph() throws {
        let resolver = DependencyGraphResolver(data: [])
        
        // Resolve dependency order
        let order = try resolver.resolve()
        XCTAssertTrue(order.isEmpty)
    }
}

extension DependencyModule {
    static func fixture(name: String = "Module",
                        type: DependencyModule.ModuleType = .struct,
                        scope: DependencyModule.Scope = .transient,
                        imports: Set<String> = ["Framework"],
                        types: Set<Dependency>) -> DependencyModule {
        return DependencyModule(type: type, imports: imports, name: name, scope: scope, types: types)
    }
}

extension Dependency {
    static func fixture(type: String,
                        name: String? = nil,
                        block: String = "block",
                        parameters: [Parameter] = [],
                        dependencies: [String: String?] = [:]) -> Dependency {
        let mergedParameters = parameters + dependencies.map {
            Dependency.Parameter(type: $0, name: nil, value: nil, dependencyId: $1)
        }
        return Dependency(dependencyType: .method,
                          name: name,
                          type: type,
                          block: block,
                          parameters: mergedParameters)
    }
}
