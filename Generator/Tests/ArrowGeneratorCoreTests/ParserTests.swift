import SwiftParser
import SwiftSyntax
import XCTest

@testable import ArrowGeneratorCore

final class ParserTests: XCTestCase {
  func testParsing_allTypes() throws {
    for type in DependencyModule.ModuleType.allCases {
      // expected
      let expectedModules: Set<DependencyModule> = .fixture(
        type: type,
        types: [
          .init(
            dependencyType: .variable,
            name: nil,
            type: "Delegate",
            block: "delegate",
            parameters: [])
        ])

      // given
      let content = createContent(
        type: type.rawValue,
        """
            var delegate: Delegate {
                Delegate()
            }
        """)

      // when
      let modules = try parse(content)

      // then
      XCTAssertEqual(modules, expectedModules)
    }
  }

  func testParsing_allScopes() throws {
    for scope in DependencyModule.Scope.allCases {
      // expected
      let expectedModules: Set<DependencyModule> = .fixture(
        scope: scope,
        types: [
          .init(
            dependencyType: .variable,
            name: nil,
            type: "Delegate",
            block: "delegate",
            parameters: [])
        ])

      // given
      let content = createContent(
        scope: scope.rawValue,
        """
            var delegate: Delegate {
                Delegate()
            }
        """)

      // when
      let modules = try parse(content)

      // then
      XCTAssertEqual(modules, expectedModules)
    }
  }

  func testSkipParsing_noScopeDefined() throws {
    // given
    let content = createContent(
      scope: "",
      """
          var delegate: Delegate {
              Delegate()
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, [])
  }

  func testParsingVariables() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .variable,
        name: nil,
        type: "Delegate",
        block: "delegate",
        parameters: [])
    ])

    // given
    let content = createContent(
      """
          var delegate: Delegate {
              Delegate()
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingMethod_withoutParameters() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .method,
        name: nil,
        type: "Service",
        block: "provideService",
        parameters: [])
    ])

    // given
    let content = createContent(
      """
          func provideService() -> Service {
              Service()
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingMethod_oneParameterWithoutName_dependecy() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .method,
        name: nil,
        type: "ViewModel",
        block: "provideViewModel",
        parameters: [.fixture(type: "Delegate", name: "_")])
    ])

    // given
    let content = createContent(
      """
          func provideViewModel(_ delegate: Delegate) -> ViewModel {
              ViewModel(delegate: delegate, factory: Factory())
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingMethod_oneParameterWithoutName_namedDependecy() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .method,
        name: nil,
        type: "ViewModel",
        block: "provideViewModel",
        parameters: [
          .fixture(type: "Delegate", name: "_", dependencyId: "AnotherDelegate")
        ])
    ])

    // given
    let content = createContent(
      """
          func provideViewModel(@Named("AnotherDelegate") _ delegate: Delegate) -> ViewModel {
              ViewModel(delegate: delegate, factory: Factory())
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingMethod_parametersWithoutNames_depedency() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .method,
        name: nil,
        type: "ViewModel",
        block: "provideViewModel",
        parameters: [
          .fixture(type: "Delegate", name: "_"),
          .fixture(type: "Factory", name: "_"),
        ])
    ])

    // given
    let content = createContent(
      """
          func provideViewModel(_ delegate: Delegate, _ factory: Factory) -> ViewModel {
              ViewModel(delegate: delegate, factory: factory)
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingMethod_oneParameters_defaultValue_noDepedency() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .method,
        name: nil,
        type: "Factory",
        block: "provideFactory",
        parameters: [.fixture(type: "Delegate", name: "delegate", value: "Delegate()")])
    ])

    // given
    let content = createContent(
      """
          func provideFactory(delegate: Delegate = Delegate()) -> Factory {
              Factory(delegate, service: Service(name: "", value: 0))
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingMethod_oneParameter_oneDependency() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .method,
        name: nil,
        type: "ExtraModel",
        block: "provideModel",
        parameters: [.fixture(type: "Delegate", name: "delegate")])
    ])

    // given
    let content = createContent(
      """
          func provideModel(delegate: Delegate) -> ExtraModel {
              ExtraModel(service: Service(name: "", value: 0))
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingMethod_oneParameter_namedDependency() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .method,
        name: "AnotherExtraModel",
        type: "ExtraModel",
        block: "provideExtraModel",
        parameters: [.fixture(type: "Delegate", name: "delegate")])
    ])

    // given
    let content = createContent(
      """
          @Name("AnotherExtraModel")
          func provideExtraModel(delegate: Delegate) -> ExtraModel {
              ExtraModel(service: Service(name: "", value: 0))
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingVariable_namedDependency() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .variable,
        name: "AnotherExtraModel",
        type: "ExtraModel",
        block: "provideExtraModel",
        parameters: [])
    ])

    // given
    let content = createContent(
      """
          @Name("AnotherExtraModel")
          var provideExtraModel: ExtraModel {
              ExtraModel(service: Service(name: "", value: 0))
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingMethod_oneParameter_namedDependency_withEnum() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .method,
        name: nil,
        type: "ExtraModel",
        block: "provideExtraModel",
        parameters: [.fixture(type: "Delegate", name: "delegate")])
    ])

    // given
    let content = createContent(
      """
          enum Test {
              case test
          }

          func provideExtraModel(delegate: Delegate) -> ExtraModel {
              ExtraModel(service: Service(name: "", value: 0))
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsingMethod_returnsTuple_dependency() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(
        dependencyType: .method,
        name: nil,
        type: "(ExtraModel, String)",
        block: "provideExtraModel",
        parameters: [.fixture(type: "Delegate", name: "delegate")])
    ])

    // given
    let content = createContent(
      """
          func provideExtraModel(delegate: Delegate) -> (ExtraModel, String) {
              (ExtraModel(service: Service(name: "", value: 0)), "")
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testSkipParsingVoidMethod() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [])

    // given
    let content = createContent(
      """
          @Name("AnotherExtraModel")
          func provideExtraModel(delegate: Delegate) {
              ExtraModel(service: Service(name: "", value: 0))
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testSkipParsingStoredVariables() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [])

    // given
    let content = createContent(
      """
          let delegate = Delegate()
          let service: Service = Service()
          var factory = Factory()
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testUnsupportedProviders_areRejected() {
    // given
    let content = createContent(
      """
          func provideAsync() async -> Service { Service() }
          func provideThrowing() throws -> Service { Service() }
          func provideBoth() async throws -> Service { Service() }
          func provideGeneric<T>() -> T { fatalError() }
          var effectful: Service { get async { Service() } }
          let stored: Service
          private func helper() throws -> Int { 0 }
      """)

    // when, then
    XCTAssertThrowsError(try parse(content)) { error in
      guard case ParserError.unsupportedProviders(let diagnostics) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(
        diagnostics,
        [
          "Module.swift:5:9: error: `Module.provideAsync` is `async`, but the registry can't await it.",
          "Module.swift:6:5: error: `Module.provideThrowing` throws, but the registry can't handle errors.",
          "Module.swift:7:5: error: `Module.provideBoth` is `async throws`, but the registry can't await or handle errors.",
          "Module.swift:8:5: error: `Module.provideGeneric` is generic, so the registry can't infer its type arguments.",
          "Module.swift:9:5: error: `Module.effectful` is `async`, but the registry can't await it.",
          "Module.swift:10:5: error: `Module.stored` is a stored property without an initializer, "
            + "so the module can't be created with `init()`. Make it a computed property.",
        ])
    }
  }

  func testSkipParsing_privateAndStaticMembers() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(dependencyType: .method, name: nil, type: "Service", block: "provideService", parameters: [])
    ])

    // given
    let content = createContent(
      """
          func provideService() -> Service { Service() }
          private func makeFormatter() -> DateFormatter { DateFormatter() }
          fileprivate var helper: Helper { Helper() }
          static func shared() -> Module { Module() }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsing_privateSetVariable() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(dependencyType: .variable, name: nil, type: "Cache", block: "cache", parameters: [])
    ])

    // given
    let content = createContent(
      """
          public private(set) var cache: Cache {
              get { Cache() }
              set {}
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testSkipParsing_nestedTypesAndLocalFunctions() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(dependencyType: .method, name: nil, type: "Service", block: "provideService", parameters: [])
    ])

    // given
    let content = createContent(
      """
          func provideService() -> Service {
              func makeHelper() -> Helper { Helper() }
              return Service(helper: makeHelper())
          }

          struct Builder {
              func build() -> Product { Product() }
          }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsing_ifConfigMembers() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(dependencyType: .method, name: nil, type: "Logger", block: "provideLogger", parameters: [])
    ])

    // given
    let content = createContent(
      """
          #if DEBUG
          func provideLogger() -> Logger { ConsoleLogger() }
          #endif
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules.map(\.name), expectedModules.map(\.name))
    XCTAssertEqual(modules.first?.types.map(\.id), expectedModules.first?.types.map(\.id))
    XCTAssertEqual(modules.first?.types.first?.condition.expression, "DEBUG")
  }

  func testParsing_ifConfigBranches_keepTheirConditions() throws {
    // given
    let content = createContent(
      """
          #if DEBUG
          func provideLogger() -> Logger { ConsoleLogger() }
          #elseif os(iOS) && BETA
          func provideBetaLogger() -> Logger { BetaLogger() }
          #else
          func provideReleaseLogger() -> Logger { NoopLogger() }
          #endif
      """)

    // when
    let types = try parse(content).first?.types ?? []
    let conditions = Dictionary(uniqueKeysWithValues: types.map { ($0.block, $0.condition.expression) })

    // then
    XCTAssertEqual(
      conditions,
      [
        "provideLogger": "DEBUG",
        "provideBetaLogger": "!DEBUG && (os(iOS) && BETA)",
        "provideReleaseLogger": "!DEBUG && !(os(iOS) && BETA)",
      ])
  }

  func testParsing_declarationImports_importTheirModule() throws {
    // given
    let content = """
      import struct Networking.Request
      import func Logging.log
      import Foundation.NSString

      struct Module: TransientScope {}
      """

    // when
    let imports = try parse(content).first?.imports

    // then
    XCTAssertEqual(imports, ["Networking", "Logging", "Foundation.NSString"])
  }

  func testParsing_conditionalImport() throws {
    // given
    let content = """
      import Arrow
      #if canImport(UIKit)
      import UIKit
      #endif

      final class Module: TransientScope {
          func provideService() -> Service { Service() }
      }
      """

    // when
    let module = try parse(content).first

    // then
    XCTAssertEqual(module?.imports, ["Arrow"])
    XCTAssertEqual(module?.conditionalImports, ["UIKit": "canImport(UIKit)"])
  }

  func testParsing_importsAfterModule() throws {
    // given
    let content = """
      final class Module: TransientScope {
          func provideService() -> Service { Service() }
      }

      import Networking
      """

    // then
    XCTAssertEqual(try parse(content).first?.imports, ["Networking"])
  }

  func testParsing_nestedModules_useQualifiedNames() throws {
    // given
    let content = """
      import Arrow

      struct Outer {
          class Inner: TransientScope {
              var service: Service { Service() }
          }
      }

      extension Feature {
          enum Namespace {
              struct Module: SingletonScope {
                  var logger: Logger { Logger() }
              }
          }
      }

      struct Factory {
          func make() -> Service {
              struct Local: TransientScope {
                  var cache: Cache { Cache() }
              }
              return Service()
          }
      }
      """

    // when
    let names = try parse(content).map(\.name).sorted()

    // then
    XCTAssertEqual(names, ["Feature.Namespace.Module", "Outer.Inner"])
  }

  func testParsing_qualifiedScope() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(
      scope: .singleton,
      types: [
        .init(dependencyType: .method, name: nil, type: "Service", block: "provideService", parameters: [])
      ])

    // given
    let content = createContent(
      scope: "Arrow.\(DependencyModule.Scope.singleton.rawValue)",
      """
          func provideService() -> Service { Service() }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsing_nameAttributeMatchesExactly() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(dependencyType: .method, name: "Primary", type: "Service", block: "providePrimary", parameters: []),
      .init(dependencyType: .method, name: "Secondary", type: "Service", block: "provideSecondary", parameters: []),
      .init(dependencyType: .method, name: nil, type: "Service", block: "provideOther", parameters: []),
    ])

    // given
    let content = createContent(
      """
          @Name("Primary")
          func providePrimary() -> Service { Service() }

          @Arrow.Name("Secondary")
          func provideSecondary() -> Service { Service() }

          @Renamed("Ignored")
          func provideOther() -> Service { Service() }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }

  func testParsing_nameDocCommentMarker() throws {
    // expected
    let expectedModules: Set<DependencyModule> = .fixture(types: [
      .init(dependencyType: .method, name: "Primary", type: "Service", block: "providePrimary", parameters: []),
      .init(dependencyType: .variable, name: "Secondary", type: "Service", block: "secondary", parameters: []),
      .init(dependencyType: .method, name: "Macro", type: "Service", block: "provideMacro", parameters: []),
      .init(dependencyType: .method, name: nil, type: "Service", block: "provideOther", parameters: []),
    ])

    // given
    let content = createContent(
      """
          /// The primary service.
          /// @Name("Primary")
          func providePrimary() -> Service { Service() }

          /// @Name("Secondary")
          var secondary: Service { Service() }

          /// @Name("Ignored")
          @Name("Macro")
          func provideMacro() -> Service { Service() }

          // @Name("Ignored")
          /// Mentions @Name("Ignored") mid-sentence.
          func provideOther() -> Service { Service() }
      """)

    // when
    let modules = try parse(content)

    // then
    XCTAssertEqual(modules, expectedModules)
  }
}

private extension ParserTests {
  func parse(_ content: String) throws -> Set<DependencyModule> {
    let tree = Parser.parse(source: content)
    let syntaxVisitor = DependencyModulesParser(viewMode: .all)
    return try syntaxVisitor.parse(tree, fileName: "Module.swift")
  }

  func createContent(
    type: String = "class",
    scope: String = DependencyModule.Scope.transient.rawValue,
    _ content: String
  ) -> String {
    """
    import Arrow
    import Another

    \(type) Module\(scope.isEmpty ? "" : ":") \(scope) {
        \(content)
    }
    """
  }
}

extension Set<DependencyModule> {
  static func fixture(
    type: DependencyModule.ModuleType = .class,
    scope: DependencyModule.Scope = .transient,
    types: Set<Dependency>
  ) -> Self {
    [
      .init(
        type: type,
        imports: ["Arrow", "Another"],
        name: "Module",
        scope: scope,
        types: types)
    ]
  }
}

extension Dependency.Parameter {
  static func fixture(
    type: String,
    name: String? = nil,
    value: String? = nil,
    dependencyId: String? = nil
  ) -> Self {
    .init(type: type, name: name, value: value, dependencyId: dependencyId)
  }
}
