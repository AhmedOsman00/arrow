# Arrow Generator

[![PR Quality Check](https://github.com/AhmedOsman00/arrow-generator/actions/workflows/pr-check.yml/badge.svg)](https://github.com/AhmedOsman00/arrow-generator/actions/workflows/pr-check.yml)
[![Release](https://github.com/AhmedOsman00/arrow-generator/actions/workflows/release.yml/badge.svg)](https://github.com/AhmedOsman00/arrow-generator/actions/workflows/release.yml)

A Swift command-line tool that automatically generates dependency injection container registration code for the [Arrow](https://github.com/AhmedOsman00/Arrow) dependency injection framework.

## Overview

Arrow Generator scans your Swift files for dependency modules (classes, structs, or extensions conforming to `SingletonScope`, `LazySingletonScope` or `TransientScope`), analyzes their dependency graph, and generates a `dependencies.generated.swift` file containing a `DependencyRegistry` with properly ordered registration code.

This eliminates the tedious and error-prone task of manually writing dependency registration code while ensuring correct initialization order through automatic dependency graph resolution.

## Features

- **Automatic Dependency Discovery**: Scans Swift files and finds all dependency modules
- **Graph Resolution**: Automatically determines correct registration order
- **Validation**: Detects missing, duplicate, and circular dependencies
- **Named Dependencies**: Supports `@Name("...")` and `@Named("...")` attributes for multiple instances of the same type
- **Default Parameters**: Handles methods with default parameter values
- **Dual Mode**: Works with both Xcode projects and Swift Packages
- **Xcode Integration**: Runs from a Run Script build phase using Xcode's environment

## Prerequisites

- macOS 10.15 or later
- Swift 6.2.1 or later
- Xcode (for Xcode project mode)

## Installation

### Homebrew (Recommended)

```bash
brew tap AhmedOsman00/homebrew-tap
brew install AhmedOsman00/tap/arrow
```

To upgrade to the latest version:

```bash
brew upgrade arrow
```

### From Source

```bash
# Clone the repository
git clone <repository-url>
cd arrow-generator

# Automated setup (recommended) - installs all dependencies and configures environment
make bootstrap

# Build the project
make build

# The executable will be in bin/arrow
./bin/arrow --help
```

**What `make bootstrap` does:**
1. Checks for Homebrew (provides installation instructions if missing)
2. Installs Mint and other tools from `Brewfile`
3. Installs SwiftLint and other Swift tools from `Mintfile`
4. Installs git hooks for automated linting
5. Verifies your development environment

### Add to PATH (Optional)

```bash
# Copy to a directory in your PATH
sudo cp bin/arrow /usr/local/bin/

# Or create a symlink
sudo ln -s $(pwd)/bin/arrow /usr/local/bin/arrow
```

## Usage

Arrow Generator has two modes: **Xcode project mode** (the default) and **Swift Package mode** (`--is-package`). Each run generates one `DependencyRegistry` type, so every app target and every package that declares modules gets its own registry.

### Xcode Project Mode

Scans the Swift files under the project root, plus any package sources you pass, and overwrites an existing `dependencies.generated.swift`. The generator does not add the file to your project, so create an empty `dependencies.generated.swift` and add it to your target once.

```bash
arrow generate \
  --proj-root /path/to/YourApp \
  --registry-name AppDependencies
```

By default the file is written to `<proj-root>/dependencies.generated.swift`. Use `--ext-path` to point somewhere else. Without `--registry-name`, the registry is named after `PRODUCT_MODULE_NAME` (or `TARGET_NAME`), for example `MyAppDependencies`, falling back to `AppDependencies`.

**Xcode Build Phase Integration**

Inside a Run Script phase or a scheme pre-action with build settings, `--proj-root` falls back to Xcode's `PROJECT_DIR`, so no arguments are needed:

1. Add a new "Run Script Phase" in your target's Build Phases
2. Add the script:
   ```bash
   if which arrow >/dev/null; then
     arrow generate
   else
     echo "warning: Arrow Generator not installed"
   fi
   ```
3. Move the phase before "Compile Sources"

### Swift Package Mode

Use this mode for Swift Packages. The file is written into the first sources directory you pass, and the registry is `public` so the app can register it. It is named after that directory (`Sources/Analytics` gives `AnalyticsDependencies`) unless you pass `--registry-name`:

```bash
arrow generate \
  --is-package \
  --package-path Sources/Analytics
```

To regenerate easily, add the command to a `Makefile` target or a script in your package.

### Dependencies From Other Registries

When a module uses a dependency that another registry provides (for example an app module that needs `Analytics` from `AnalyticsDependencies`), pass that registry's sources with `--external-path`. They are used to validate and order the graph, but nothing from them is generated. This also works when the package lives inside the app's project root:

```bash
arrow generate \
  --proj-root . \
  --external-path Packages/Analytics/Sources/Analytics
```

At startup, register registries before the ones that depend on them, because eager singletons are created during registration:

```swift
Container.shared.register(AnalyticsDependencies.self, AppDependencies.self)
```

## Writing Dependency Modules

Dependency modules are classes, structs, or extensions that conform to `SingletonScope`, `LazySingletonScope` or `TransientScope`.

### Basic Example

```swift
import Arrow

final class AppModule: SingletonScope {
    // Computed property providing a dependency
    var apiClient: APIClient {
        APIClient(baseURL: "https://api.example.com")
    }

    // Method providing a dependency with parameters
    func userRepository(apiClient: APIClient) -> UserRepository {
        UserRepository(apiClient: apiClient)
    }
}
```

### Named Dependencies

Use `@Name("...")` to declare named dependencies and `@Named("...")` to inject them:

```swift
final class ConfigModule: SingletonScope {
    @Name("Production")
    var prodAPI: APIClient {
        APIClient(baseURL: "https://api.production.com")
    }

    @Name("Staging")
    var stagingAPI: APIClient {
        APIClient(baseURL: "https://api.staging.com")
    }
}

final class ServiceModule: SingletonScope {
    // Inject a named dependency using @Named
    func userService(@Named("Production") apiClient: APIClient) -> UserService {
        UserService(apiClient: apiClient)
    }
}
```

### Default Parameters

Methods can have default parameter values for non-injected dependencies:

```swift
final class ViewModelModule: TransientScope {
    func homeViewModel(
        repository: UserRepository,
        config: Config = Config.default
    ) -> HomeViewModel {
        HomeViewModel(repository: repository, config: config)
    }
}
```

### Scopes

- **SingletonScope**: Dependencies are created once, during registration, and reused
- **LazySingletonScope**: Dependencies are created once, on first resolve, and reused
- **TransientScope**: New instance created each time

### Rules

1. Only computed properties (not stored properties) are considered
2. Only methods with return types are scanned (void methods are ignored)
3. All parameters without default values are treated as dependencies
4. Use `@Name("...")` on declarations to create named dependencies
5. Use `@Named("...")` on method parameters to inject named dependencies

## Generated Output

Arrow Generator creates a `dependencies.generated.swift` file. `name:` is only emitted for `@Name`/`@Named` dependencies; everything else is keyed by its type, so `@Inject` and `resolve(_:)` find it without a name:

```swift
// Generated by arrow. Do not edit.

import Arrow

enum AppDependencies: DependencyRegistry {
  static func register(in container: Container) {
    let appModule = AppModule()
    let configModule = ConfigModule()
    let serviceModule = ServiceModule()
    let viewModelModule = ViewModelModule()

    container.register(APIClient.self, objectScope: .singleton) { resolver in
      appModule.apiClient
    }

    container.register(APIClient.self, name: "Production", objectScope: .singleton) { resolver in
      configModule.prodAPI
    }

    container.register(APIClient.self, name: "Staging", objectScope: .singleton) { resolver in
      configModule.stagingAPI
    }

    container.register(UserRepository.self, objectScope: .singleton) { resolver in
      appModule.userRepository(
        apiClient: resolver.resolve(APIClient.self)
      )
    }

    container.register(UserService.self, objectScope: .singleton) { resolver in
      serviceModule.userService(
        apiClient: resolver.resolve(APIClient.self, name: "Production")
      )
    }

    container.register(HomeViewModel.self, objectScope: .transient) { resolver in
      viewModelModule.homeViewModel(
        repository: resolver.resolve(UserRepository.self)
      )
    }
  }
}
```

In package mode the enum and `register(in:)` are `public`.

### Using the Generated Code

```swift
import Arrow

// Setup container
Container.shared.register(AppDependencies.self)

// Resolve dependencies
let viewModel: HomeViewModel = Container.shared.resolve(HomeViewModel.self)
let prodAPI: APIClient = Container.shared.resolve(APIClient.self, name: "Production")
```

## Command-Line Options

```
arrow generate [OPTIONS]

OPTIONS:
  -v                             Enable verbose logging
  --is-package                   Enable Swift Package mode instead of Xcode project mode
  --proj-root <path>             Root path of the project (falls back to PROJECT_DIR)
  --ext-path <path>              Path to an existing dependencies.generated.swift
                                 (defaults to <proj-root>/dependencies.generated.swift)
  --package-path <path>          Path to a Swift Package sources directory
                                 (can be specified multiple times)
  --external-path <path>         Sources of dependencies provided by another registry;
                                 used for validation only (can be specified multiple times)
  --registry-name <name>         Name of the generated registry type
                                 (defaults to <name>Dependencies)
  --version                      Show the version
  --help                         Show help information
```

## Error Handling

Arrow Generator validates your dependency graph and reports:

- **Missing Dependencies**: When a required dependency isn't provided
- **Duplicate Dependencies**: When the same dependency is defined multiple times
- **Circular Dependencies**: When dependencies form a cycle

Example error:

```
Error: Circular dependency detected: _:UserRepository -> _:APIClient -> _:TokenManager -> _:UserRepository
```

## Contributing

Contributions are welcome! Please see our [Contributing Guide](project-docs/CONTRIBUTING.md) for details on:

- Development setup
- Code style and standards
- Testing guidelines
- Pull request process
- Project architecture overview
