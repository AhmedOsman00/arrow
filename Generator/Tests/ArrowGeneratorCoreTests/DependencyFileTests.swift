import XCTest

@testable import ArrowGeneratorCore

class DependencyFileTests: XCTestCase {
  func testValidOutput() throws {
    let expectedOutput = """
      import Arrow

      extension Container {
        func register() {
          let module = Module()

          self.register(Type.self, name: "Type", objectScope: .transient) { resolver in
            module.provide(
              resolver.resolve(B.self, name: "B"), 
              a: resolver.resolve(A.self, name: "A"), 
              c: resolver.resolve(C.self, name: "cType")
            )
          }
        }
      }
      """

    var file = ""
    DependencyFile(presenter: DependencyFilePresenterMock(.fixture())).file.write(to: &file)
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
            module.provide(
              resolver.resolve(B.self, name: "B"), 
              a: resolver.resolve(A.self, name: "A"), 
              c: resolver.resolve(C.self, name: "cType")
            )
          }

          self.register(ExtraType.self, name: "ExtraTypeName", objectScope: .singleton) { resolver in
            extramodule.provide(
              resolver.resolve(Z.self, name: "Z"), 
              q: resolver.resolve(Q.self, name: "qType"), 
              e: resolver.resolve(E.self, name: "E")
            )
          }

          self.register(VariableType.self, name: "VariableTypeName", objectScope: .singleton) { resolver in
            extramodule.provideVariable
          }

          self.register(MoreType.self, name: "MoreType", objectScope: .singleton) { resolver in
            extramodule.provideMoreType()
          }

          self.register(Type2.self, name: "MoreType2", objectScope: .singleton) { resolver in
            extramodule.provideTypeTwo(
              resolver.resolve(A.self, name: "A")
            )
          }
        }
      }
      """

    var file = ""
    let dependencies: [DependencyUiModel] = [
      .fixture(),
      .fixture(
        module: "ExtraModule",
        type: "ExtraType",
        name: "ExtraTypeName",
        block: "provide",
        scope: "singleton",
        parameters: [
          .init(type: "Z", label: nil, id: "Z", isLast: false),
          .init(type: "Q", label: "q", id: "qType", isLast: false),
          .init(type: "E", label: "e", id: "E", isLast: true),
        ]),
      .fixture(
        module: "ExtraModule",
        isFunc: false,
        type: "VariableType",
        name: "VariableTypeName",
        block: "provideVariable",
        scope: "singleton"),
      .fixture(
        module: "ExtraModule",
        type: "MoreType",
        name: "MoreType",
        block: "provideMoreType",
        scope: "singleton",
        parameters: []),
      .fixture(
        module: "ExtraModule",
        type: "Type2",
        name: "MoreType2",
        block: "provideTypeTwo",
        scope: "singleton",
        parameters: [
          .init(type: "A", label: nil, id: "A", isLast: true)
        ]),
    ]
    DependencyFile(presenter: DependencyFilePresenterMock(.fixture(dependencies: dependencies)))
      .file
      .write(to: &file)
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
    isFunc: Bool = true,
    type: String = "Type",
    name: String = "Type",
    block: String = "provide",
    scope: String = "transient",
    parameters: [Parameter] = .default
  ) -> Self {
    .init(
      id: .init(""),
      module: module,
      isFunc: isFunc,
      type: type,
      name: name,
      block: block,
      scope: scope,
      parameters: parameters)
  }
}

extension Array where Element == DependencyUiModel.Parameter {
  static let `default`: [Element] = [
    .init(type: "B", label: nil, id: "B", isLast: false),
    .init(type: "A", label: "a", id: "A", isLast: false),
    .init(type: "C", label: "c", id: "cType", isLast: true),
  ]
}
