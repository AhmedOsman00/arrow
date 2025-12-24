# Building a Swift Code Generation CLI: The Arrow Generator Story

## Introduction

Dependency injection is powerful, but manually registering dependencies in a DI container is tedious and error-prone. After writing registration code for the hundredth time—and debugging initialization order issues for what felt like the millionth time—I decided to automate it.

This is the story of building **Arrow Generator**, a Swift command-line tool that scans your codebase, analyzes dependency relationships, and generates perfectly ordered registration code automatically.

## The Problem

When using the Arrow dependency injection framework, you need to manually write code like this:

```swift
extension Container {
    func registerApp() {
        let module = AppModule()

        self.register(APIClient.self, name: "APIClient", objectScope: .singleton) { resolver in
            module.apiClient
        }

        self.register(UserRepository.self, name: "UserRepository", objectScope: .singleton) { resolver in
            module.userRepository(apiClient: resolver.resolved())
        }

        // ... potentially hundreds more lines
    }
}
```

The problems with this approach:

1. **Tedious**: Every new dependency requires boilerplate code
2. **Error-Prone**: Easy to misspell names or forget dependencies
3. **Initialization Order**: Dependencies must be registered in the right order
4. **Maintenance Burden**: Refactoring dependencies means updating registration code
5. **Scalability**: Large projects can have hundreds of dependencies

## The Vision

I wanted a tool that would:

1. Scan Swift files to find dependency modules
2. Extract dependencies and their relationships
3. Validate the dependency graph (detect cycles, missing deps)
4. Generate registration code in the correct order
5. Integrate seamlessly with Xcode and Swift Package Manager

## Technology Stack

### Why Swift?

The obvious choice. I'm generating Swift code for Swift projects, so using Swift provides:

- Native understanding of the language
- Easy integration with Swift projects
- Access to powerful Swift libraries

### Key Dependencies

After researching the Swift ecosystem, I settled on these libraries:

#### 1. **SwiftSyntax** (Apple's official parser)

```swift
.package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "602.0.0")
```

**Why?** It's the official Swift AST parser from Apple. It gives you a complete, accurate syntax tree of any Swift code.

**How I use it:**
- Parse Swift files into Abstract Syntax Trees
- Visit specific syntax nodes (classes, functions, variables)
- Generate new Swift code with proper formatting

#### 2. **ConsoleKit** (Vapor's CLI framework)

```swift
.package(url: "https://github.com/vapor/console-kit.git", exact: "4.15.2")
```

**Why?** It provides a robust command-line interface with argument parsing, help generation, and error handling.

**How I use it:**
- Define commands with typed arguments
- Automatic help text generation
- Professional CLI experience

#### 3. **XcodeProj** (Tuist's Xcode parser)

```swift
.package(url: "https://github.com/tuist/XcodeProj.git", exact: "9.6.0")
```

**Why?** To read `.xcodeproj` files and extract source files from targets.

**How I use it:**
- Parse Xcode project structure
- Extract Swift files from specific targets
- Add generated files back to the project

#### 4. **PathKit** (File path utilities)

```swift
.package(url: "https://github.com/kylef/PathKit.git", exact: "1.0.1")
```

**Why?** Clean, Swift-friendly file path manipulation.

## Architecture: The Pipeline Pattern

I organized the tool as a data pipeline with seven distinct stages:

```
Input (Xcode/SPM) → Parsing → Domain Models → Graph Resolution
                  → Presentation → Code Generation → Output
```

### Stage 1: Entry Point & Command Setup

```swift
// main.swift
let console = Terminal()
var commands = Commands(enableAutocomplete: true)
commands.use(DependencyRegistrationGenerator(), as: Constants.generateCommand, isDefault: true)

do {
    let group = commands.group(help: "Arrow Dependency Generator")
    try console.run(group, input: CommandLine.arguments)
} catch {
    console.error("\(error)")
    exit(1)
}
```

Simple and clean. ConsoleKit handles all the heavy lifting.

### Stage 2: File Discovery

The tool needs to work with both Xcode projects and Swift Packages:

```swift
// Xcode Mode
let xcodeParser = try XcodeFileParser(
    project: try XcodeProj(path: xcodeProjPath),
    xcodeProjPath: xcodeProjPath,
    target: targetName
)
let swiftFiles = try xcodeParser.parse()

// Package Mode
let swiftFiles = try sourcesPath.recursiveChildren()
    .filter { $0.extension == "swift" }
    .map { $0.string }
```

**Key Decision:** Support both modes from day one. Many projects use Swift Package Manager for modular architecture, so SPM support was essential.

### Stage 3: Parsing with SwiftSyntax

This is where things get interesting. I needed to:

1. Find classes/structs/extensions that conform to scope protocols
2. Extract their dependencies (methods and computed properties)
3. Handle `@Named` macros for named dependencies

I used SwiftSyntax's **Visitor Pattern**:

```swift
final class DependencyModulesParser: SyntaxVisitor {
    private var modules: [DependencyModule] = []

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.inheritanceClause?.containsScopeProtocol == true {
            let module = extractModule(from: node)
            modules.append(module)
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        // Similar logic for structs
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // Similar logic for extensions
    }
}
```

**Why the Visitor Pattern?** It's perfect for AST traversal. You override only the node types you care about, and SwiftSyntax handles the tree walking.

### Stage 4: Domain Models

I created clean, testable domain models:

```swift
struct DependencyModule: Hashable {
    enum ModuleType: String, CaseIterable {
        case `class`, `struct`, `extension`
    }

    enum Scope: String, CaseIterable {
        case singleton = "SingletonScope"
        case transient = "TransientScope"
    }

    let type: ModuleType
    let imports: Set<String>
    let name: String
    let scope: Scope
    let dependencies: Set<Dependency>
}

struct Dependency: Hashable {
    enum DependencyType: String, CaseIterable {
        case variable, method
    }

    let dependencyType: DependencyType
    let name: String?  // From @Named macro
    let type: String   // Return type
    let block: String  // Method/property name
    let parameters: [Parameter]
}
```

**Key Decision:** Use value types (structs) for immutability and make them `Hashable` for easy Set operations.

### Stage 5: Dependency Graph Resolution

The most complex part: resolving the dependency graph and detecting issues.

```swift
final class DependencyGraphResolver {
    func resolveAndValidate() throws -> [String] {
        // 1. Build the graph
        let graph = buildGraph()

        // 2. Validate
        try validateNoDuplicates()
        try validateNoMissingDependencies(graph: graph)
        try validateNoCycles(graph: graph)

        // 3. Topological sort
        return try topologicalSort(graph: graph)
    }

    private func topologicalSort(graph: [String: Set<String>]) throws -> [String] {
        var visited = Set<String>()
        var visiting = Set<String>()
        var result: [String] = []

        func visit(_ node: String) throws {
            if visiting.contains(node) {
                throw ResolutionError.circularDependency(node)
            }

            guard !visited.contains(node) else { return }

            visiting.insert(node)

            for dependency in graph[node] ?? [] {
                try visit(dependency)
            }

            visiting.remove(node)
            visited.insert(node)
            result.insert(node, at: 0)
        }

        for node in graph.keys {
            try visit(node)
        }

        return result
    }
}
```

**The Algorithm:** Depth-first search with cycle detection. The `visiting` set tracks the current DFS path, detecting cycles immediately.

**Why Topological Sort?** It ensures dependencies are registered before the types that depend on them.

### Stage 6: Presentation Layer

Before generating code, I transform domain models into "UI models" optimized for code generation:

```swift
struct FileUiModel {
    let imports: Set<String>
    let dependencies: [DependencyUiModel]
}

struct DependencyUiModel {
    let module: String
    let type: String
    let name: String
    let block: String
    let scope: String
    let parameters: [Parameter]

    struct Parameter {
        let name: String?
        let value: String?
        let id: String?
        let isLast: Bool  // For comma handling
    }
}
```

**Why a separate layer?** Clean separation between business logic and code generation. The presenter handles concerns like:

- Deduplicating imports
- Sorting dependencies by resolved order
- Formatting parameter lists
- Lowercasing module instance names

### Stage 7: Code Generation

Using SwiftSyntax's builder API to generate perfectly formatted code:

```swift
final class DependencyFile {
    let file: SourceFileSyntax

    init(presenter: DependencyFilePresenting, registerSuffix: String) {
        let model = presenter.present()

        self.file = SourceFileSyntax {
            // Import statements
            for importName in model.imports.sorted() {
                ImportDeclSyntax(path: [ImportPathComponentSyntax(name: .identifier(importName))])
            }

            // Extension declaration
            ExtensionDeclSyntax(
                extendedType: IdentifierTypeSyntax(name: .identifier("Container"))
            ) {
                // Function declaration
                FunctionDeclSyntax(
                    name: .identifier("register\(registerSuffix)")
                ) {
                    // Module instantiations
                    for module in model.uniqueModules {
                        let instanceName = module.lowercased()
                        VariableDeclSyntax(...)
                    }

                    // Registration calls
                    for dependency in model.dependencies {
                        generateRegistration(for: dependency)
                    }
                }
            }
        }
    }
}
```

**Why SwiftSyntax Builders?** They generate syntactically correct, properly formatted Swift code automatically. No string concatenation nightmares!

## Challenges & Solutions

### Challenge 1: Understanding SwiftSyntax

**Problem:** SwiftSyntax is powerful but has a steep learning curve. The AST structure is complex.

**Solution:**
- Wrote small test programs to explore the AST
- Used `dump()` to print syntax trees
- Built incrementally, adding support for one syntax node at a time

### Challenge 2: Handling Named Dependencies

**Problem:** Parameters with `@Named("...")` attributes need special handling.

**Solution:** Parse macro attributes during dependency extraction:

```swift
func extractNamedAttribute(from attributes: AttributeListSyntax?) -> String? {
    for attribute in attributes ?? [] {
        if let attr = attribute.as(AttributeSyntax.self),
           attr.attributeName.description == Constants.namedProperty,
           let args = attr.arguments?.as(LabeledExprListSyntax.self),
           let stringLiteral = args.first?.expression.as(StringLiteralExprSyntax.self) {
            return stringLiteral.segments.first?.description
        }
    }
    return nil
}
```

### Challenge 3: Circular Dependency Detection

**Problem:** Need to detect cycles and report the cycle path for debugging.

**Solution:** Track the DFS path in a separate set:

```swift
var visiting = Set<String>()

func visit(_ node: String) throws {
    if visiting.contains(node) {
        throw ResolutionError.circularDependency(Array(visiting) + [node])
    }
    visiting.insert(node)
    // ... visit dependencies
    visiting.remove(node)
}
```

### Challenge 4: Testing

**Problem:** How do you test code that parses files and generates code?

**Solution:**
1. **Protocol abstractions** for mockability
2. **String-based fixtures** for input
3. **String comparison** for output validation

```swift
func testValidOutput() {
    let expectedOutput = """
    import Arrow

    extension Container {
        func registerMain() {
            // ...
        }
    }
    """

    var file = ""
    DependencyFile(presenter: mock, registerSuffix: "Main")
        .file.write(to: &file)

    XCTAssertEqual(expectedOutput, file)
}
```

## Lessons Learned

### 1. Start with the Domain Model

I spent time upfront designing clean domain models. This paid off massively:
- Easy to reason about
- Simple to test
- Clear boundaries between layers

### 2. Separation of Concerns is Critical

The pipeline architecture made development incremental:
- Each stage could be built and tested independently
- Easy to add new features to specific stages
- Clear data flow through the system

### 3. SwiftSyntax is Worth Learning

Yes, it's complex. But it's the only reliable way to parse and generate Swift code. String manipulation would have been a nightmare.

### 4. Test Early, Test Often

I wrote tests alongside implementation. This caught bugs immediately:
- Parser tests ensure correct AST traversal
- Resolver tests validate graph algorithms
- Generator tests verify output format

### 5. Real-World Testing is Essential

Unit tests are great, but nothing beats testing on a real codebase. I used the tool on actual projects to find edge cases.

## Results

The tool successfully:

- **Saves Time**: What took 30 minutes manually now takes seconds
- **Eliminates Errors**: No more typos or forgotten dependencies
- **Scales**: Handles projects with hundreds of dependencies
- **Integrates Seamlessly**: Works in Xcode build phases
- **Provides Confidence**: Validation catches issues before runtime

## Future Improvements

Some ideas for v2:

1. **Watch Mode**: Regenerate on file changes during development
2. **Performance**: Cache parsed files, only process changed files
3. **IDE Integration**: Xcode Source Editor Extension
4. **Custom Scopes**: Support user-defined scope protocols
5. **Documentation**: Generate dependency graph visualizations
6. **Multi-Container**: Support multiple DI containers

## Conclusion

Building Arrow Generator taught me:

- The power of AST-based code generation
- How to design maintainable CLI tools
- The importance of validation and error messages
- That automation is worth the investment

If you're building Swift tooling, I hope this article gives you insights and ideas. The combination of SwiftSyntax, ConsoleKit, and a clean architecture can take you far.

The full source code is available at [repository URL]. Feel free to explore, use, and contribute!

## Key Takeaways

✅ Use official tools (SwiftSyntax) for parsing
✅ Design clean domain models first
✅ Separate concerns with pipeline architecture
✅ Test each layer independently
✅ Validate early, fail fast with clear errors
✅ Real-world testing finds edge cases
✅ Good error messages save debugging time

---

**About the Author**

[Your bio here]

**Resources**

- [Arrow Dependency Injection Framework](link)
- [SwiftSyntax Documentation](https://github.com/apple/swift-syntax)
- [ConsoleKit](https://github.com/vapor/console-kit)
- [XcodeProj](https://github.com/tuist/XcodeProj)

---

*Have questions or suggestions? Open an issue or PR on [GitHub](repository-url)!*
