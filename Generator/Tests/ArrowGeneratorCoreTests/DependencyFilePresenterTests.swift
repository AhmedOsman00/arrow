import XCTest
@testable import ArrowGeneratorCore

final class DependencyFilePresenterTests: XCTestCase {
    
    func testFileUiModel_ImportsAndDependenciesAreCorrect() {
        // Arrange
        let modules: [DependencyModule] = [
            .fixture(name: "Module1", scope: .singleton, imports: ["Import1", "Import2"], types: [
                .fixture(type: "Type1", name: nil, block: "Block1", parameters: [
                    .init(type: "ParamType1", name: "_", value: nil, dependencyId: nil),
                    .init(type: "ParamType2", name: "Param2", value: "Value2", dependencyId: nil),
                    .init(type: "ParamType3", name: "_", value: nil, dependencyId: nil),
                    .init(type: "ParamType3", name: "Param3", value: nil, dependencyId: "paramType3")
                ]),
                .fixture(type: "Type1", name: "type1Alias", block: "Block2", parameters: [])
            ]),
            .fixture(name: "Module2", scope: .transient, imports: ["Import2", "Import3"], types: [
                .fixture(type: "Type3", name: "Dependency3", block: "Block3", parameters: [
                    .init(type: "ParamType1", name: "Param3", value: nil, dependencyId: nil)
                ])
            ])
        ]
        
        let dependenciesOrder = ["Dependency3:Type3", "Type1:Type1", "type1Alias:Type1"]
        let presenter = DependencyFilePresenter(data: modules, dependenciesOrder: dependenciesOrder)
        
        // Act
        let fileUiModel = presenter.fileUiModel
        
        // Assert
        // Verify imports
        XCTAssertEqual(fileUiModel.imports, ["Import1", "Import2", "Import3"])
        XCTAssertEqual(fileUiModel.modules, ["Module2", "Module1"])
        
        // Verify Dependency1 details
        let dependency1 = fileUiModel.dependencies[1]
        XCTAssertEqual(dependency1.module, "Module1")
        XCTAssertEqual(dependency1.type, "Type1")
        XCTAssertEqual(dependency1.name, "Type1")
        XCTAssertEqual(dependency1.block, "Block1")
        XCTAssertEqual(dependency1.scope, "singleton")
        XCTAssertEqual(dependency1.parameters[0].name, nil)
        XCTAssertEqual(dependency1.parameters[0].value, nil)
        XCTAssertEqual(dependency1.parameters[0].id, nil)
        XCTAssertEqual(dependency1.parameters[1].name, "Param2")
        XCTAssertEqual(dependency1.parameters[1].value, "Value2")
        XCTAssertEqual(dependency1.parameters[1].id, nil)
        XCTAssertEqual(dependency1.parameters[2].name, nil)
        XCTAssertEqual(dependency1.parameters[2].value, nil)
        XCTAssertEqual(dependency1.parameters[2].id, nil)
        XCTAssertEqual(dependency1.parameters[3].name, "Param3")
        XCTAssertEqual(dependency1.parameters[3].value, nil)
        XCTAssertEqual(dependency1.parameters[3].id, "paramType3")

        // Verify Dependency2 details
        let dependency2 = fileUiModel.dependencies[2]
        XCTAssertEqual(dependency2.module, "Module1")
        XCTAssertEqual(dependency2.type, "Type1")
        XCTAssertEqual(dependency2.name, "type1Alias")
        XCTAssertEqual(dependency2.block, "Block2")
        XCTAssertEqual(dependency2.scope, "singleton")
        XCTAssertEqual(dependency2.parameters.count, 0)

        // Verify Dependency3 details
        let dependency3 = fileUiModel.dependencies[0]
        XCTAssertEqual(dependency3.module, "Module2")
        XCTAssertEqual(dependency3.type, "Type3")
        XCTAssertEqual(dependency3.name, "Dependency3")
        XCTAssertEqual(dependency3.block, "Block3")
        XCTAssertEqual(dependency3.scope, "transient")
        XCTAssertEqual(dependency3.parameters[0].name, "Param3")
        XCTAssertEqual(dependency3.parameters[0].value, nil)
    }
}
