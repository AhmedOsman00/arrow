import XCTest
import SwiftSyntax
import SwiftParser
@testable import Script

final class ParserTests: XCTestCase {
    
    func testParsing_allTypes() {
        for type in DependencyModule.ModuleType.allCases {
            //expected
            let expectedModules: Set<DependencyModule> = .fixture(type: type, types: [
                .init(dependencyType: .variable,
                      name: "Delegate",
                      type: "Delegate",
                      block: "delegate",
                      parameters: []),
            ])
            
            //given
            let content = createContent(type: type.rawValue, """
                var delegate: Delegate {
                    Delegate()
                }
            """)
            
            //when
            let modules = parse(content)
            
            //then
            XCTAssertEqual(modules, expectedModules)
        }
    }
    
    func testParsing_allScopes() {
        for scope in DependencyModule.Scope.allCases {
            //expected
            let expectedModules: Set<DependencyModule> = .fixture(scope: scope, types: [
                .init(dependencyType: .variable,
                      name: "Delegate",
                      type: "Delegate",
                      block: "delegate",
                      parameters: []),
            ])
            
            //given
            let content = createContent(scope: scope.rawValue, """
                var delegate: Delegate {
                    Delegate()
                }
            """)
            
            //when
            let modules = parse(content)
            
            //then
            XCTAssertEqual(modules, expectedModules)
        }
    }
    
    func testSkipParsing_noScopeDefined() {
        //given
        let content = createContent(scope: "", """
            var delegate: Delegate {
                Delegate()
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, [])
    }
    
    func testParsingVariables() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [
            .init(dependencyType: .variable,
                  name: "Delegate",
                  type: "Delegate",
                  block: "delegate",
                  parameters: []),
        ])
        
        //given
        let content = createContent("""
            var delegate: Delegate {
                Delegate()
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testParsingMethod_withoutParameters() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [
            .init(dependencyType: .method,
                  name: nil,
                  type: "Service",
                  block: "provideService",
                  parameters: [])
        ])
        
        //given
        let content = createContent("""
            func provideService() -> Service {
                Service()
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testParsingMethod_oneParameterWithoutName_dependecy() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [
            .init(dependencyType: .method,
                  name: nil,
                  type: "ViewModel",
                  block: "provideViewModel",
                  parameters: [.init(type: "Delegate", name: "_", value: nil)]),
        ])
        
        //given
        let content = createContent("""
            func provideViewModel(_ delegate: Delegate) -> ViewModel {
                ViewModel(delegate: delegate, factory: Factory())
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testParsingMethod_parametersWithoutNames_depedency() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [
            .init(dependencyType: .method,
                  name: nil,
                  type: "ViewModel",
                  block: "provideViewModel",
                  parameters: [.init(type: "Delegate", name: "_", value: nil),
                               .init(type: "Factory", name: "_", value: nil)]),
        ])
        
        //given
        let content = createContent("""
            func provideViewModel(_ delegate: Delegate, _ factory: Factory) -> ViewModel {
                ViewModel(delegate: delegate, factory: factory)
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testParsingMethod_oneParameters_defaultValue_noDepedency() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [
            .init(dependencyType: .method,
                  name: nil,
                  type: "Factory",
                  block: "provideFactory",
                  parameters: [.init(type: "Delegate", name: "delegate", value: "Delegate()")]),
        ])
        
        //given
        let content = createContent("""
            func provideFactory(delegate: Delegate = Delegate()) -> Factory {
                Factory(delegate, service: Service(name: "", value: 0))
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testParsingMethod_oneParameter_oneDependency() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [
            .init(dependencyType: .method,
                  name: nil,
                  type: "ExtraModel",
                  block: "provideModel",
                  parameters: [.init(type: "Delegate", name: "delegate", value: nil)]),
        ])
        
        //given
        let content = createContent("""
            func provideModel(delegate: Delegate) -> ExtraModel {
                ExtraModel(service: Service(name: "", value: 0))
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testParsingMethod_oneParameter_namedDependency() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [
            .init(dependencyType: .method,
                  name: "AnotherExtraModel",
                  type: "ExtraModel",
                  block: "provideExtraModel",
                  parameters: [.init(type: "Delegate", name: "delegate", value: nil)]),
        ])
        
        //given
        let content = createContent("""
            @Named("AnotherExtraModel")
            func provideExtraModel(delegate: Delegate) -> ExtraModel {
                ExtraModel(service: Service(name: "", value: 0))
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testParsingMethod_oneParameter_namedDependency_withEnum() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [
            .init(dependencyType: .method,
                  name: nil,
                  type: "ExtraModel",
                  block: "provideExtraModel",
                  parameters: [.init(type: "Delegate", name: "delegate", value: nil)]),
        ])
        
        //given
        let content = createContent("""
            enum Test {
                case test
            }
            
            func provideExtraModel(delegate: Delegate) -> ExtraModel {
                ExtraModel(service: Service(name: "", value: 0))
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testParsingMethod_returnsTuple_dependency() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [
            .init(dependencyType: .method,
                  name: nil,
                  type: "(ExtraModel, String)",
                  block: "provideExtraModel",
                  parameters: [.init(type: "Delegate", name: "delegate", value: nil)]),
        ])
        
        //given
        let content = createContent("""
            func provideExtraModel(delegate: Delegate) -> (ExtraModel, String) {
                (ExtraModel(service: Service(name: "", value: 0)), "")
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testSkipParsingVoidMethod() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [])
        
        //given
        let content = createContent("""
            @Named("AnotherExtraModel")
            func provideExtraModel(delegate: Delegate) {
                ExtraModel(service: Service(name: "", value: 0))
            }
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
    
    func testSkipParsingStoredVariables() {
        //expected
        let expectedModules: Set<DependencyModule> = .fixture(types: [])
        
        //given
        let content = createContent("""
            let delegate = Delegate()
            let service: Service = Service()
            var factory = Factory()
        """)
        
        //when
        let modules = parse(content)
        
        //then
        XCTAssertEqual(modules, expectedModules)
    }
}

private extension ParserTests {
    func parse(_ content: String) -> Set<DependencyModule> {
        let tree = Parser.parse(source: content)
        let syntaxVisitor = ModuleParser(viewMode: .all)
        return syntaxVisitor.parse(tree)
    }
    
    func createContent(type: String = "class",
                       scope: String = DependencyModule.Scope.transient.rawValue,
                       _ content: String) -> String {
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
    static func fixture(type: DependencyModule.ModuleType = .class,
                        scope: DependencyModule.Scope = .transient,
                        types: Set<Dependency>) -> Set<DependencyModule> {
        [
            .init(type: type,
                  imports: ["Arrow", "Another"],
                  name: "Module",
                  scope: scope,
                  types: types)
        ]
    }
}
