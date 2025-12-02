import XCTest
@testable import ArrowGeneratorCore

class DependencyFileTests: XCTestCase {
    
    func testValidOutput() throws {
        let expectedOutput = """
import Arrow

extension Container {
    func registerMain() {
        let module = Module()

        self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
            module.provide(resolver.resolved(), a: resolver.resolved(), b: B(), c: resolver.resolved("cType"))
        }
    }
}
"""
        
        var file = ""
        DependencyFile(presenter: DependencyFilePresenterMock(.fixture()), registerSuffix: "Main").file.write(to: &file)
        XCTAssertEqual(expectedOutput, file)
    }
    
    func testValidOutput_moreModules() throws {
        let expectedOutput = """
import Arrow

extension Container {
    func register() {
        let module = Module()
        let extramodule = ExtraModule()

        self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
            module.provide(resolver.resolved(), a: resolver.resolved(), b: B(), c: resolver.resolved("cType"))
        }

        self.register(ExtraType.self, name: "ExtraType", objectScope: .singleton) { resolver in
            extramodule.provide(resolver.resolved(), q: resolver.resolved("qType"), e: resolver.resolved())
        }
    }
}
"""
        
        var file = ""
        let dependencies: [DependencyUiModel] = [
            .fixture(),
            .fixture(module: "ExtraModule",
                     type: "ExtraType",
                     name: "ExtraType",
                     block: "provide",
                     scope: "singleton",
                     parameters: [
                        .init(name: nil, value: nil, id: nil, isLast: false),
                        .init(name: "q", value: nil, id: "qType", isLast: false),
                        .init(name: "e", value: nil, id: nil, isLast: true),
                     ])
        ]
        DependencyFile(presenter: DependencyFilePresenterMock(.fixture(dependencies: dependencies)), registerSuffix: "").file.write(to: &file)
        XCTAssertEqual(expectedOutput, file)
    }
}

struct DependencyFilePresenterMock: DependencyFilePresenting {
    let fileUiModel: FileUiModel
    
    init(_ uiModel: FileUiModel) {
        self.fileUiModel = uiModel
    }
}

extension FileUiModel {
    static func fixture(
        imports: Set<String> = ["Arrow"],
        dependencies: [DependencyUiModel] = [.fixture()]
    ) -> Self {
        .init(imports: imports, dependencies: dependencies)
    }
}

extension DependencyUiModel {
    static func fixture(
        module: String = "Module",
        type: String = "Type",
        name: String = "Type",
        block: String = "provide",
        scope: String = "transient",
        parameters: [Parameter] = .default
    ) -> Self {
        .init(module: module,
              type: type,
              name: name,
              block: block,
              scope: scope,
              parameters: parameters)
    }
}

extension Array where Element == DependencyUiModel.Parameter {
    static let `default`: [Element] = [
        .init(name: nil, value: nil, id: nil, isLast: false),
        .init(name: "a", value: nil, id: nil, isLast: false),
        .init(name: "b", value: "B()", id: nil, isLast: false),
        .init(name: "c", value: nil, id: "cType", isLast: true),
      ]
}
