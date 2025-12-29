# Arrow Generator Architecture

This document describes the architecture and design of the Arrow Generator tool.

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Core Components](#core-components)
- [Data Flow](#data-flow)
- [Key Design Decisions](#key-design-decisions)
- [Extension Points](#extension-points)

## Overview

Arrow Generator is a Swift command-line tool that generates dependency injection container registration code for the [Arrow](https://github.com/AhmedOsman00/Arrow) DI framework. It analyzes Swift source code to discover dependency modules, validates the dependency graph, and generates properly ordered registration code.

### Goals

1. **Automation**: Eliminate manual dependency registration boilerplate
2. **Correctness**: Ensure dependencies are registered in the correct order
3. **Validation**: Catch dependency configuration errors at build time
4. **Integration**: Seamless integration with Xcode projects and Swift packages

## System Architecture

The tool follows a pipeline architecture with five main stages:

```
┌─────────────────┐
│  File Discovery │  (XcodeFileParser / Directory Scanning)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Parsing     │  (DependencyModulesParser, DependenciesParser)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Graph Resolution│  (DependencyGraphResolver)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Code Generation │  (DependencyFilePresenter, DependencyFile)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Integration   │  (Write file, update Xcode project)
└─────────────────┘
```

### Operational Modes

The tool supports two operational modes:

#### Xcode Project Mode
- Uses `XcodeFileParser` to extract Swift files from `.xcodeproj`
- Automatically adds generated file to the project
- Supports additional package sources via `--package-sources-path`

#### Swift Package Mode
- Directly scans a sources directory
- Does not modify any project files
- Typically invoked via the [Arrow Generator Plugin](https://github.com/AhmedOsman00/arrow-generator-plugin)

## Core Components

### 1. Command Layer

**Location**: `Sources/ArrowGeneratorCore/Commands/`

#### DependencyRegistrationGenerator
The main command entry point implementing `ParsableCommand` from Swift Argument Parser.

**Responsibilities**:
- Parse command-line arguments
- Coordinate the generation pipeline
- Handle both Xcode and package modes

**Key Methods**:
- `run()`: Main execution entry point
- `generateDependenciesFile()`: Core generation pipeline
- `parse(files:)`: Swift file parsing orchestration

### 2. File Discovery Layer

**Location**: `Sources/ArrowGeneratorCore/XcodeFileParser/`

#### XcodeFileParser
Extracts Swift file paths from Xcode projects using the XcodeProj library.

**Responsibilities**:
- Parse `.xcodeproj` files
- Extract Swift source files from a specific target
- Add generated files to the project

**Key APIs**:
- `parse()`: Returns array of Swift file paths
- `addFile(path:)`: Adds file to project and build phases
- `isFileAlreadyAdded(path:)`: Checks for existing files

### 3. Parsing Layer

**Location**: `Sources/ArrowGeneratorCore/SwiftFilesParsers/`

This layer uses Apple's `swift-syntax` library to parse Swift source code.

#### DependencyModulesParser
Visitor pattern implementation that identifies dependency modules.

**Detects**:
- Classes, structs, and extensions
- Conformance to `SingletonScope` or `TransientScope`
- Import statements

**Output**: Set of `DependencyModule` instances

#### DependenciesParser
Nested visitor that extracts individual dependency definitions from modules.

**Detects**:
- Computed properties (dependencies without parameters)
- Methods with return types (dependency factories)
- `@Named("...")` attributes on declarations
- `@Named("...")` attributes on method parameters
- Parameter types and default values

**Output**: Set of `Dependency` instances

### 4. Data Models

**Location**: `Sources/ArrowGeneratorCore/Dtos/`

#### DependencyModule
Represents a type that provides dependencies.

**Properties**:
- `type`: class, struct, or extension
- `scope`: singleton or transient
- `imports`: Required import statements
- `types`: Set of dependencies provided

#### Dependency
Represents a single dependency declaration.

**Properties**:
- `dependencyType`: variable or method
- `name`: Optional name from `@Named` attribute
- `type`: Return type
- `parameters`: Array of parameters
- `id`: Unique identifier (format: `"name:type"`)

#### Dependency.Parameter
Represents a method parameter.

**Properties**:
- `type`: Swift type
- `name`: Parameter label
- `value`: Default value (if any)
- `dependencyId`: Named dependency reference

### 5. Graph Resolution Layer

**Location**: `Sources/ArrowGeneratorCore/DependencyGraphResolver/`

#### DependencyGraphResolver
Validates and resolves the dependency graph using topological sorting.

**Validations**:
1. **Missing dependencies**: All referenced types must be provided
2. **Duplicate dependencies**: No two dependencies can have the same type/name
3. **Circular dependencies**: No cycles in the dependency graph (detected via DFS)

**Algorithm**: Depth-first search with cycle detection for topological sorting.

**Output**: Array of dependency IDs in registration order

### 6. Code Generation Layer

**Location**: `Sources/ArrowGeneratorCore/DependencyFileGenerator/`

#### DependencyFilePresenter
Transforms parsed data into UI models suitable for code generation.

**Responsibilities**:
- Map `DependencyModule` → `DependencyUiModel`
- Sort dependencies by topological order
- Collect all required imports

#### DependencyFile
Generates Swift source code using SwiftSyntax builders.

**Generates**:
- Import declarations
- `Container` extension
- `register()` method
- Module instantiations
- Dependency registration calls with closures

**Output**: `SourceFileSyntax` (SwiftSyntax AST)

## Data Flow

### Detailed Pipeline Flow

```
1. File Discovery
   Input:  Xcode project path + target name OR sources directory
   Output: Array of Swift file paths

2. Parsing
   Input:  Swift file paths
   Parse:  Each file → Syntax tree → Dependency modules
   Output: [DependencyModule]

3. Graph Resolution
   Input:  [DependencyModule]
   Build:  Adjacency list graph (dependency → [dependencies])
   Validate:
     - Check all dependencies exist
     - Check no duplicates
     - Detect cycles using DFS
   Sort:   Topological ordering
   Output: [String] (ordered dependency IDs)

4. Code Generation
   Input:  [DependencyModule] + [String] (order)
   Transform:
     - Modules → UI models
     - Sort by topological order
     - Collect imports
   Generate:
     - SwiftSyntax AST
     - Render to string
   Output: Swift source code string

5. Integration
   Input:  Generated code + output path
   Write:  File to disk
   Update: Xcode project (if applicable)
```

### Dependency Identification

A dependency is identified by its **ID** which combines type and optional name:

```
Format: "{name}:{type}"

Examples:
  "_:APIClient"              // Unnamed APIClient
  "production:APIClient"     // Named "production" APIClient
  "_:NetworkService"         // Unnamed NetworkService
```

This ID format enables:
- Unique identification across modules
- Named dependency disambiguation
- Graph traversal and topological sorting

## Key Design Decisions

### 1. Why SwiftSyntax for Code Generation?

**Decision**: Use SwiftSyntax builders instead of string templates

**Rationale**:
- **Type safety**: Compile-time guarantees for valid Swift syntax
- **Maintainability**: Easier to update when Swift syntax changes
- **Correctness**: Automatic handling of trivia (whitespace, newlines)
- **Extensibility**: Easy to add new code generation patterns

**Trade-off**: More verbose code, steeper learning curve

### 2. Why Topological Sorting?

**Decision**: Use DFS-based topological sort for dependency ordering

**Rationale**:
- **Correctness**: Guarantees dependencies are registered before dependents
- **Efficiency**: O(V + E) time complexity
- **Cycle detection**: Inherently detects circular dependencies
- **Deterministic**: Same input always produces same order

### 3. Why Two-Level Parsing?

**Decision**: Separate module discovery from dependency extraction

**Rationale**:
- **Separation of concerns**: Module-level vs member-level parsing
- **Reusability**: Can parse dependencies from any declaration node
- **Clarity**: Clear distinction between module metadata and dependency details

### 4. Named Dependencies Design

**Decision**: Support `@Named("...")` on both declarations and parameters

**Rationale**:
- **Disambiguation**: Multiple instances of the same type
- **Flexibility**: Can have "production" and "test" API clients
- **Clarity**: Explicit naming at both definition and usage sites

**Implementation**:
```swift
// Definition site
@Named("production")
var apiClient: APIClient { ... }

// Usage site
func service(client: @Named("production") APIClient) -> Service { ... }
```

### 5. Why Validate Before Generate?

**Decision**: Fail fast with clear error messages

**Rationale**:
- **Developer experience**: Catch errors before generating invalid code
- **Build integration**: Clear error messages at build time
- **Safety**: Prevents registration-time crashes

**Error Types**:
```swift
- Missing dependencies: "Missing dependencies: NetworkService"
- Duplicates: "Duplicate dependencies found: APIClient"
- Cycles: "Circular dependency detected at 'ServiceA' with dependencies: ServiceB -> ServiceC -> ServiceA"
```

## Extension Points

### Adding New Scope Types

To support additional scope types beyond singleton/transient:

1. Update `DependencyModule.Scope` enum in `Dtos/DependencyModule.swift`
2. Keep synchronized with Arrow framework protocols
3. Update generated code in `DependencyFile.swift` to use new scope

### Adding New Dependency Patterns

To recognize new dependency declaration patterns:

1. Extend `DependenciesParser` visit methods
2. Add pattern recognition logic
3. Ensure proper `Dependency` instance creation
4. Add tests in `ParserTests`

### Custom Code Generation

To customize generated code structure:

1. Modify `DependencyFile` SwiftSyntax builders
2. Update trivia for formatting preferences
3. Consider UI model changes in `DependencyFilePresenter`

### Integration with Other Tools

The tool can be integrated into:
- **Xcode build phases**: Run script phase calling `arrow generate`
- **Swift Package plugins**: Use the [Arrow Generator Plugin](https://github.com/AhmedOsman00/arrow-generator-plugin)
- **CI/CD pipelines**: Validate generated code is up-to-date
- **Pre-commit hooks**: Auto-generate on file changes

## Performance Considerations

### Parsing Performance
- **Lazy evaluation**: UI models computed lazily
- **Set operations**: Fast lookups for validation
- **Single pass**: Each file parsed once

### Memory Usage
- **Syntax trees**: Released after parsing each file
- **Graph representation**: Adjacency list (space efficient)
- **Generated code**: Built incrementally via SwiftSyntax

### Optimization Opportunities
1. **Parallel parsing**: Parse multiple files concurrently
2. **Incremental generation**: Only reparse changed files
3. **Caching**: Cache parsed modules between runs

## Testing Strategy

The codebase uses different test types for different components:

### Unit Tests
- **DependencyGraphResolverTests**: Graph validation and sorting
- **ParserTests**: Swift syntax parsing correctness
- **DependencyFilePresenterTests**: UI model transformation

### Integration Tests
- **DependencyFileTests**: End-to-end code generation
- **XCodeParserTests**: Xcode project integration

### Test Principles
- Descriptive naming: `test{Component}_{Scenario}_{Expectation}`
- Isolated tests: No shared state between tests
- Edge cases: Empty inputs, cycles, missing deps, duplicates

## Related Documentation

- [README.md](README.md): User-facing documentation and usage
- [Arrow Framework](https://github.com/AhmedOsman00/Arrow): The DI framework this tool supports
- [Arrow Generator Plugin](https://github.com/AhmedOsman00/arrow-generator-plugin): SPM plugin wrapper
