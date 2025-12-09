# Contributing to Arrow Generator

Thank you for your interest in contributing to Arrow Generator! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Code Style and Standards](#code-style-and-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Project Architecture](#project-architecture)
- [Reporting Issues](#reporting-issues)

## Getting Started

Before you begin:

1. Check existing [issues](https://github.com/AhmedOsman00/arrow-generator/issues) to see if your concern has already been reported
2. For new features, consider opening an issue first to discuss your proposal
3. For bug fixes, feel free to submit a PR directly with a clear description

## Development Setup

### Prerequisites

- macOS 10.15 or later
- Swift 6.2 or later
- Xcode (optional, but recommended for development)
- SwiftLint (for code style enforcement)

### Installing SwiftLint

```bash
brew install swiftlint
```

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/AhmedOsman00/arrow-generator.git
cd arrow-generator

# Build the project
make build

# Run tests
make test

# Install git hooks for automatic linting
make install-hooks
```

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 2. Make Your Changes

Follow the [Code Style and Standards](#code-style-and-standards) guidelines below.

### 3. Run Tests and Linting

Before committing, ensure all tests pass and code is properly formatted:

```bash
# Run tests
make test

# Run linting
make lint

# Auto-fix linting issues
make lint-fix
```

### 4. Commit Your Changes

If you installed git hooks via `make install-hooks`, SwiftLint will automatically fix and re-stage your files on commit.

```bash
git add .
git commit -m "Add clear description of your changes"
```

Write clear, descriptive commit messages:
- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Reference issues when applicable ("Fix #123: Resolve circular dependency detection")

### 5. Push and Create a Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub with:
- A clear title describing the change
- A description explaining what changed and why
- Reference to any related issues
- Screenshots or examples if applicable

## Code Style and Standards

### SwiftLint Configuration

The project uses SwiftLint to enforce code style. Configuration is in `.swiftlint.yml`.

Key style rules:
- Line length: 120 characters (warning), 150 (error)
- Function body length: 40 lines (warning), 100 (error)
- File length: 500 lines (warning), 1000 (error)
- Use explicit types when clarity is improved
- Prefer `let` over `var` when possible

### Swift Conventions

- Use meaningful, descriptive names for types, functions, and variables
- Follow Swift naming conventions:
  - `UpperCamelCase` for types and protocols
  - `lowerCamelCase` for functions, methods, variables, and constants
- Keep functions focused and single-purpose
- Add comments for complex logic, but prefer self-documenting code
- Use `// MARK: -` to organize code sections within files

### Constants Synchronization

⚠️ **IMPORTANT**: Some constants must be kept in sync across multiple files:

The following must match:
- `Sources/Constants/Constants.swift`
- `Package.swift` (executable name)
- Arrow framework macros (`@Named`, `@Name`)

Files with sync requirements have `// ⚠️ SYNC:` comments at the top.

## Testing

### Running Tests

```bash
# Run all tests
make test
# or
swift test

# Run specific test
swift test --filter DependencyGraphResolverTests

# Run a specific test case
swift test --filter DependencyGraphResolverTests.testCircularDependency
```

### Writing Tests

- Place tests in `Tests/ArrowGeneratorCoreTests/`
- Follow the naming pattern: `test{Component}_{Scenario}_{ExpectedOutcome}`
- Examples:
  - `testDependencyGraphResolver_WithCircularDependency_ThrowsError`
  - `testDependenciesParser_WithNamedDependency_ParsesCorrectly`
  - `testXcodeFileParser_WithValidProject_ReturnsSwiftFiles`

### Test Coverage

When adding new features:
- Add tests for the happy path
- Add tests for error cases
- Add tests for edge cases
- Ensure tests are meaningful and actually test the logic

Focus on testing:
- **Parsers**: Test parsing of different Swift syntax patterns
- **Dependency Graph Resolver**: Test graph validation and ordering
- **Code Generation**: Test output format and correctness
- **Error Handling**: Test that appropriate errors are thrown

## Submitting Changes

### Pull Request Checklist

Before submitting your PR, ensure:

- [ ] All tests pass (`make test`)
- [ ] Code is properly linted (`make lint`)
- [ ] New features include tests
- [ ] Bug fixes include regression tests
- [ ] Code follows the project's style guidelines
- [ ] Commit messages are clear and descriptive
- [ ] PR description explains the changes and reasoning
- [ ] Documentation is updated if needed (README.md, etc.)

### PR Review Process

1. A maintainer will review your PR
2. Address any feedback or requested changes
3. Once approved, a maintainer will merge your PR
4. Your contribution will be included in the next release

## Project Architecture

For a detailed understanding of the project architecture, refer to [ARCHITECTURE.md](ARCHITECTURE.md) which covers:

- Core pipeline flow (File Discovery → Parsing → Graph Resolution → Code Generation)
- Key components and their responsibilities
- Data models and their relationships
- Dependency resolution algorithm
- Testing architecture
- Extension points and future considerations

### Quick Component Overview

- **DependencyModulesParser**: Finds classes/structs/extensions conforming to scope protocols
- **DependenciesParser**: Extracts dependencies from module members
- **DependencyGraphResolver**: Validates and orders dependencies using topological sort
- **DependencyFilePresenter**: Maps dependencies to UI models for code generation
- **DependencyFile**: Generates the final Swift code
- **XcodeFileParser**: Parses Xcode projects to find Swift files

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed component descriptions, algorithms, and data flow.

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

- Arrow Generator version
- Swift/Xcode version
- macOS version
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Sample code that demonstrates the issue (if applicable)
- Error messages or logs

### Feature Requests

When requesting features, please:

- Clearly describe the feature and its use case
- Explain why it would be valuable to the project
- Provide examples of how it would be used
- Consider discussing it in an issue before implementing

## Questions?

If you have questions about contributing:

1. Check the [README.md](../README.md) for project documentation
2. Review existing [issues](https://github.com/AhmedOsman00/arrow-generator/issues)
3. Open a new issue with your question

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Assume good intentions

Thank you for contributing to Arrow Generator!
