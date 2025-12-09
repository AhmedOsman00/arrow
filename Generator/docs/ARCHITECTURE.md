# Arrow Generator Architecture

This document describes the internal architecture of Arrow Generator, including its core pipeline, key components, data models, and algorithms.

## Overview

Arrow Generator is a Swift command-line tool that generates dependency injection container registration code for the [Arrow](https://github.com/AhmedOsman00/Arrow) DI framework. It analyzes Swift source files, builds a dependency graph, and generates properly ordered registration code.

## Core Pipeline Flow

The tool follows a multi-stage pipeline:

```
File Discovery → Parsing → Graph Resolution → Code Generation → Project Integration
```

### 1. File Discovery

**Xcode Project Mode:**
- **XcodeFileParser** (`Sources/ArrowGeneratorCore/XcodeFileParser/`)
- Uses the XcodeProj library to parse `.xcodeproj` files
- Finds the specified target
- Extracts all Swift file paths from the target

**Swift Package Mode:**
- Directly scans the sources directory for `.swift` files
- No project parsing required

### 2. Parsing (Swift Syntax)

Two-level parsing using Apple's `swift-syntax` library:

#### Level 1: Module Discovery
**DependencyModulesParser** (`Sources/ArrowGeneratorCore/SwiftFilesParsers/DependencyModulesParser.swift`):
- Visits classes, structs, and extensions in Swift files
- Identifies those conforming to `SingletonScope` or `TransientScope` protocols
- Collects imports from each file
- Creates `DependencyModule` instances for each conforming type

#### Level 2: Dependency Extraction
**DependenciesParser** (`Sources/ArrowGeneratorCore/SwiftFilesParsers/DependenciesParser.swift`):
- Scans members of discovered dependency modules
- Identifies computed properties (variables without initializers)
- Identifies methods with return types (void methods are ignored)
- Extracts `@Named("...")` attributes from:
  - Dependency declarations (properties/methods)
  - Method parameters (to reference named dependencies)
- Creates `Dependency` instances with:
  - Type and name information
  - Parameter details (name, type, default values)
  - Named dependency references

**Parsing Rules:**
- Only computed properties are considered dependencies (stored properties are ignored)
- Only methods with return types are scanned (void methods are skipped)
- Parameters without default values are treated as dependencies
- Parameters with default values are preserved but not treated as graph dependencies

### 3. Graph Resolution

**DependencyGraphResolver** (`Sources/ArrowGeneratorCore/DependencyGraphResolver/DependencyGraphResolver.swift`):

Builds and validates a dependency graph, then returns a topologically sorted order for registration.

#### Dependency ID Format
Each dependency is identified by: `TypeName_NameIfProvided`

Examples:
- Named dependency: `APIClient_Production`
- Unnamed dependency: `APIClient_APIClient`

#### Validation Checks

1. **Missing Dependencies**
   - Ensures all referenced dependencies are provided
   - Checks that parameters in one dependency can be resolved by other dependencies

2. **Duplicate Dependencies**
   - Ensures the same type/name combination is not defined multiple times
   - Prevents ambiguous registrations

3. **Circular Dependencies**
   - Uses Depth-First Search (DFS) traversal to detect cycles
   - Prevents infinite resolution loops at runtime

#### Topological Sorting
- Orders dependencies so that each dependency is registered after all its parameters
- Ensures the generated code registers dependencies in the correct order
- Uses DFS-based topological sort algorithm

### 4. Code Generation

#### Step 1: Model Mapping
**DependencyFilePresenter** (`Sources/ArrowGeneratorCore/DependencyFileGenerator/DependencyFilePresenter.swift`):
- Maps `DependencyModule` and `Dependency` instances to UI models
- Sorts dependencies according to the graph resolution order
- Prepares data for code generation

#### Step 2: Swift Code Generation
**DependencyFile** (`Sources/ArrowGeneratorCore/DependencyFileGenerator/DependencyFile.swift`):
- Generates Swift source code for a `Container` extension
- Creates a `register{TargetName}()` method containing:
  - Module instantiations (e.g., `let module = NetworkModule()`)
  - Dependency registrations in topologically sorted order
  - Proper `resolver.resolve()` calls for parameters
  - Named dependency registrations with names

**Generated Code Structure:**
```swift
import Arrow
import Foundation
// ... other imports

extension Container {
    func registerMyTarget() {
        let module1 = FirstModule()
        let module2 = SecondModule()

        // Dependencies registered in sorted order
        register(singleton: module1.database)
        register(singleton: module2.apiClient) { resolver in
            resolver.resolve(Database.self)
        }
        // ... more registrations
    }
}
```

### 5. Project Integration

**Xcode Mode:**
- Writes `dependencies.generated.swift` to the project directory
- Automatically adds the file to the Xcode project (if not already present)
- Uses XcodeProj library to modify `.xcodeproj` file

**Package Mode:**
- Writes `dependencies.generated.swift` to the sources directory
- No project file modification needed (SPM automatically includes all Swift files)

## Key Components

### Parsers

#### XcodeFileParser
- **Location**: `Sources/ArrowGeneratorCore/XcodeFileParser/`
- **Purpose**: Parses Xcode project files to find Swift source files
- **Dependencies**: XcodeProj library
- **Key Methods**:
  - Finds target by name
  - Extracts file references
  - Returns absolute paths to Swift files

#### DependencyModulesParser
- **Location**: `Sources/ArrowGeneratorCore/SwiftFilesParsers/DependencyModulesParser.swift`
- **Purpose**: Discovers classes/structs/extensions that conform to scope protocols
- **Dependencies**: swift-syntax library
- **Key Methods**:
  - `visit(_: ClassDeclSyntax)`: Visits class declarations
  - `visit(_: StructDeclSyntax)`: Visits struct declarations
  - `visit(_: ExtensionDeclSyntax)`: Visits extension declarations

#### DependenciesParser
- **Location**: `Sources/ArrowGeneratorCore/SwiftFilesParsers/DependenciesParser.swift`
- **Purpose**: Extracts dependency definitions from module members
- **Dependencies**: swift-syntax library
- **Key Methods**:
  - `visit(_: VariableDeclSyntax)`: Visits property declarations
  - `visit(_: FunctionDeclSyntax)`: Visits method declarations
  - `getName()`: Helper to extract `@Named` attribute values

### Graph Resolution

#### DependencyGraphResolver
- **Location**: `Sources/ArrowGeneratorCore/DependencyGraphResolver/DependencyGraphResolver.swift`
- **Purpose**: Validates dependency graph and determines registration order
- **Algorithm**: DFS-based topological sort with cycle detection
- **Key Methods**:
  - `resolve()`: Main entry point for graph resolution
  - Cycle detection using DFS
  - Duplicate and missing dependency validation

### Code Generation

#### DependencyFilePresenter
- **Location**: `Sources/ArrowGeneratorCore/DependencyFileGenerator/DependencyFilePresenter.swift`
- **Purpose**: Maps domain models to presentation models
- **Key Responsibilities**:
  - Sorts dependencies by resolution order
  - Prepares data for code generation
  - Creates UI models for templates

#### DependencyFile
- **Location**: `Sources/ArrowGeneratorCore/DependencyFileGenerator/DependencyFile.swift`
- **Purpose**: Generates Swift source code
- **Output**: `dependencies.generated.swift` file
- **Key Responsibilities**:
  - Generates import statements
  - Generates `Container` extension
  - Generates registration method with:
    - Module instantiations
    - Dependency registrations
    - Resolver parameter calls

## Key Data Models

### DependencyModule
- **Location**: `Sources/ArrowGeneratorCore/Dtos/DependencyModule.swift`
- **Purpose**: Represents a class/struct/extension that provides dependencies
- **Properties**:
  - `name`: Module name
  - `scope`: `.singleton` or `.transient`
  - `imports`: Import statements from the file
  - `dependencies`: List of `Dependency` instances provided by this module

### Dependency
- **Location**: `Sources/ArrowGeneratorCore/Dtos/Dependency.swift`
- **Purpose**: Represents a single dependency (property or method)
- **Properties**:
  - `name`: Dependency name (from `@Named` or inferred from declaration)
  - `type`: Return type of the dependency
  - `parameters`: List of parameters (for method-based dependencies)
  - `scope`: `.singleton` or `.transient`
  - `moduleName`: Name of the module providing this dependency

#### Parameter Information
Each parameter includes:
- `name`: Parameter name
- `type`: Parameter type
- `defaultValue`: Optional default value expression
- `isNamed`: Whether the parameter references a named dependency

## Named Dependencies

The `@Named("...")` macro allows multiple instances of the same type to coexist in the container.

### Usage Patterns

1. **Named Dependency Declaration**
   ```swift
   extension NetworkModule: SingletonScope {
       @Named("Production")
       var apiClient: APIClient {
           APIClient(baseURL: "https://api.production.com")
       }
   }
   ```

2. **Named Dependency Reference**
   ```swift
   extension ServiceModule: SingletonScope {
       func userService(@Named("Production") apiClient: APIClient) -> UserService {
           UserService(apiClient: apiClient)
       }
   }
   ```

### Implementation Details
- Parsed in `DependenciesParser.swift` via the `getName()` helper
- Names are included in the dependency ID for uniqueness
- Generated code uses `resolver.resolve(APIClient.self, name: "Production")`

## Dependency Resolution Algorithm

### Graph Building
1. Create a node for each dependency
2. Create edges from each dependency to its parameter dependencies
3. Use dependency IDs (TypeName_NameIfProvided) as node keys

### Validation
1. **Missing Dependencies**: For each parameter, check if a matching dependency exists
2. **Duplicates**: Ensure no two dependencies have the same ID
3. **Cycles**: Run DFS with recursion stack tracking to detect cycles

### Topological Sort
1. Start with dependencies that have no parameters (leaf nodes)
2. Process dependencies in DFS post-order
3. Result: Dependencies are registered after their parameters

### Error Handling
- Missing dependency → Throws error with details
- Duplicate dependency → Throws error with locations
- Circular dependency → Throws error with cycle path

## Generated File

### File Name
- Always named `dependencies.generated.swift`
- Defined in `Sources/Constants/Constants.swift`

### File Content Structure
```swift
// Generated imports (from modules)
import Arrow
import Foundation
// ... other imports

// Container extension
extension Container {
    func register{TargetName}() {
        // Module instantiations
        let module1 = Module1()
        let module2 = Module2()

        // Dependency registrations (sorted order)
        register(singleton: module1.simpleProperty)

        register(transient: module2.complexMethod) { resolver in
            resolver.resolve(Dependency.self)
        }

        // Named dependencies
        register(singleton: module1.namedProperty, name: "Production")

        register(singleton: module2.namedWithParams, name: "Custom") { resolver in
            resolver.resolve(ParamType.self, name: "OtherName")
        }
    }
}
```

### SwiftLint Exclusion
- The generated file is excluded from SwiftLint via `.swiftlint.yml`
- This prevents linting issues from generated code

## Constants Synchronization

Some constants must remain synchronized across multiple files:

### Synchronized Values
- Macro names: `@Named`, `@Name`
- File names: `dependencies.generated.swift`
- Executable name in `Package.swift`

### Files to Update
1. `Sources/Constants/Constants.swift`
2. `Package.swift`
3. Arrow framework macro definitions

### Sync Warnings
Files with sync requirements have `// ⚠️ SYNC:` comments at the top, indicating which values must be kept in sync.

## Testing Architecture

### Test Organization
Tests are located in `Tests/ArrowGeneratorCoreTests/`:
- `DependencyGraphResolverTests`: Graph resolution, validation, sorting
- `DependencyFilePresenterTests`: Model mapping and sorting
- `ParserTests`: Swift syntax parsing
- `XCodeParserTests`: Xcode project parsing
- `DependencyFileTests`: Code generation output

### Test Naming Convention
Pattern: `test{Component}_{Scenario}_{ExpectedOutcome}`

Examples:
- `testDependencyGraphResolver_WithCircularDependency_ThrowsError`
- `testDependenciesParser_WithNamedDependency_ParsesCorrectly`
- `testXcodeFileParser_WithValidProject_ReturnsSwiftFiles`

### Test Coverage Focus
1. **Parsers**: Different Swift syntax patterns
2. **Graph Resolver**: Validation and ordering
3. **Code Generation**: Output format correctness
4. **Error Handling**: Appropriate error throwing

## Extension Points

### Adding New Scope Types
1. Update parser to recognize new protocols
2. Update data models to support new scope
3. Update code generation to handle new scope

### Supporting New Dependency Patterns
1. Extend `DependenciesParser` to recognize new syntax
2. Update `Dependency` model if needed
3. Update code generation templates

### Adding New Project Types
1. Create a new file parser (like `XcodeFileParser`)
2. Implement Swift file discovery logic
3. Integrate with main pipeline

## Performance Considerations

### Swift Syntax Parsing
- Parsing is done once per file
- Files are processed in parallel when possible
- Large projects may take several seconds

### Graph Resolution
- Time complexity: O(V + E) where V = dependencies, E = parameter relationships
- Generally fast even for large projects
- Cycle detection adds minimal overhead

### Code Generation
- O(n) where n = number of dependencies
- Very fast, typically completes in milliseconds

## Future Architecture Considerations

### Potential Improvements
- Incremental generation (only regenerate when sources change)
- Support for multiple targets in one run
- Caching of parsed modules
- Parallel file parsing for large projects
- Better error messages with source locations

### Plugin Architecture
The companion [Arrow Generator Plugin](https://github.com/AhmedOsman00/arrow-generator-plugin) provides SPM integration. Consider:
- Keeping the core tool independent
- Using the plugin as a thin wrapper
- Maintaining API stability between tool and plugin
