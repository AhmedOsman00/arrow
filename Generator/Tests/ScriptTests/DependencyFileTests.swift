import XCTest
@testable import Script

class DependencyFileTests: XCTestCase {
    
    func testValidOutput() throws {
        let expectedOutput = """
import Arrow

extension Container {
    func register() {
        let module = Module()

        self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
            module.provide(resolver.resolved(), a: resolver.resolved(), b: B())
        }
    }
}
"""
        
        var file = ""
        DependencyFile(DependencyFilePresenterMock()).file.write(to: &file)
        XCTAssertEqual(expectedOutput, file)
    }
}

struct DependencyFilePresenterMock: DependencyFilePresenting {
    var imports: Set<String> {
        ["Arrow"]
    }
    
    var moduleNames: Set<String> {
        ["Module"]
    }
    
    var objects: [Script.Object] {
        [
            .init(module: "Module", name: "Type", block: "provide", scope: "transient", args: [
                .init(name: nil, value: nil, comma: true),
                .init(name: "a", value: nil, comma: true),
                .init(name: "b", value: "B()", comma: false),
            ])
        ]
    }
}
