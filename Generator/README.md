# Arrow Generator

[![CI](https://github.com/AhmedOsman00/arrow/actions/workflows/ci.yml/badge.svg)](https://github.com/AhmedOsman00/arrow/actions/workflows/ci.yml)
[![Release](https://github.com/AhmedOsman00/arrow/actions/workflows/release.yml/badge.svg)](https://github.com/AhmedOsman00/arrow/actions/workflows/release.yml)

A Swift command-line tool that automatically generates dependency injection container registration code for the [Arrow](../README.md) dependency injection framework.

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
- **Xcode Integration**: Runs from a Run Script build phase, configured through build settings

## Prerequisites

- macOS 10.15 or later
- Swift 6.2.1 or later
- Xcode (for Xcode project mode)
- [Arrow](../README.md) at the same version as the generator in the project that uses the generated code. They're released together from this repository.

## Installation

### Homebrew (Recommended)

```bash
brew install --cask AhmedOsman00/tap/arrow
```

To upgrade to the latest version:

```bash
brew upgrade --cask arrow
```

### From Source

```bash
# Clone the repository
git clone https://github.com/AhmedOsman00/arrow.git
cd arrow

# Automated setup (recommended) - installs all dependencies and configures environment
make bootstrap

# Build the generator
make build-generator

# The executable will be in Generator/bin/arrow
./Generator/bin/arrow --help
```

**What `make bootstrap` does:**
1. Downloads the pinned prebuilt SwiftLint into `.tools/` (see `scripts/swiftlint.sh`)
2. Installs git hooks for automated linting
3. Verifies your development environment

### Add to PATH (Optional)

```bash
# Copy to a directory in your PATH
sudo cp Generator/bin/arrow /usr/local/bin/

# Or create a symlink
sudo ln -s $(pwd)/Generator/bin/arrow /usr/local/bin/arrow
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

### Running From Xcode

The recommended setup runs the generator from a Run Script build phase, so the registry is regenerated on every build. Xcode passes its build settings to the script as environment variables, so the script needs no arguments:

- `--proj-root` falls back to `PROJECT_DIR`
- the registry is named after `PRODUCT_MODULE_NAME` (or `TARGET_NAME`)
- every other option can be set as an `ARROW_*` build setting (see [Build Settings](#build-settings))

**1. Create the output file once.** Create an empty `dependencies.generated.swift` in the project root (or wherever `ARROW_EXT_PATH` points) and add it to your target.

**2. Disable user script sandboxing for the target.** In the target's Build Settings, set **User Script Sandboxing** (`ENABLE_USER_SCRIPT_SANDBOXING`) to **No**. Xcode 15 and later turns it on by default, and with it on the script can only read files declared as its inputs. The generator reads every Swift file in the project, so the build fails with `Sandbox: deny file-read-data` errors.

**3. Add a Run Script phase** in the target's Build Phases:

```bash
# Xcode doesn't put Homebrew on the PATH of build scripts (Apple Silicon installs to /opt/homebrew).
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

if command -v arrow >/dev/null; then
  arrow generate
else
  echo "error: Arrow Generator is not installed. Run: brew install --cask AhmedOsman00/tap/arrow"
  exit 1
fi
```

**4. Configure the phase:**
- Drag it above **Compile Sources** so the registry is up to date before the code that uses it compiles.
- Uncheck **Based on dependency analysis**. The phase then runs on every build, which is cheap: the file is rewritten only when its content changes, so an unchanged registry doesn't trigger a recompile.

The script fails the build when the generator is missing. A build that silently continues would compile an outdated registry and crash at runtime on a missing dependency.

#### Build Settings

Each option has a build setting fallback, so the script stays `arrow generate` and every target or configuration (or `.xcconfig` file) sets its own values. Command-line options take precedence.

| Build setting | Option | Example |
| --- | --- | --- |
| `ARROW_REGISTRY_NAME` | `--registry-name` | `AppDependencies` |
| `ARROW_EXT_PATH` | `--ext-path` | `$(SRCROOT)/App/Generated/dependencies.generated.swift` |
| `ARROW_PACKAGE_PATHS` | `--package-path` | `$(SRCROOT)/Packages/Core/Sources/Core` |
| `ARROW_EXTERNAL_PATHS` | `--external-path` | `$(SRCROOT)/../Shared/Analytics/Sources/Analytics` |

Add them as user-defined build settings (Build Settings → **+** → **Add User-Defined Setting**) or in an `.xcconfig`:

```
// App.xcconfig
ARROW_EXTERNAL_PATHS = $(SRCROOT)/../Shared/Analytics/Sources/Analytics $(SRCROOT)/../Shared/Network/Sources/Network
```

The two path settings take several paths separated by spaces. Quote a path that contains spaces: `"$(SRCROOT)/My Packages/Analytics"`.

### Swift Package Mode

Use this mode for Swift Packages. The file is written into the first sources directory you pass, and the registry is `public` so the app can register it. It is named after that directory (`Sources/Analytics` gives `AnalyticsDependencies`) unless you pass `--registry-name`:

```bash
arrow generate \
  --is-package \
  --package-path Sources/Analytics
```

To regenerate easily, add the command to a `Makefile` target or a script in your package.

### Dependencies From Other Registries

When a module uses a dependency that another registry provides (for example an app module that needs `Analytics` from `AnalyticsDependencies`), pass that registry's sources with `--external-path`. They are used to validate and order the graph, but nothing from them is generated.

Swift packages nested inside a scanned path (any folder below it with a `Package.swift`) are treated this way automatically, so a local package with its own registry doesn't need `--external-path`. Point `--package-path` inside a nested package to generate its providers into this registry instead. For a package outside the project root, pass its sources explicitly:

```bash
arrow generate \
  --proj-root . \
  --external-path ../Shared/Sources/Analytics
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

Use `@Name("...")` to declare named dependencies and `@Named("...")` to inject them. `@Name` is a macro in the opt-in `ArrowMacros` product, so add that product to the target and import it, or write it as a doc-comment marker instead (see below):

```swift
import Arrow
import ArrowMacros

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

The doc-comment marker names a provider the same way without the macro, so the module doesn't need `ArrowMacros` or swift-syntax. Put `@Name("...")` on its own `///` line; the `@Name` macro wins when both are present:

```swift
import Arrow

final class ConfigModule: SingletonScope {
    /// The production API.
    /// @Name("Production")
    var prodAPI: APIClient {
        APIClient(baseURL: "https://api.production.com")
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

### Optional Parameters

An optional parameter is resolved with `tryResolve`, so it's `nil` when nothing provides the wrapped type, and it's never reported as missing. A provider that returns the optional type itself (`Cache?`) still takes precedence:

```swift
final class FeedModule: TransientScope {
    // resolver.tryResolve(Cache.self)
    func feed(cache: Cache?) -> Feed { Feed(cache: cache) }
}
```

### Main Actor Modules

Generated factories are synchronous, so in Swift 6 they can't call a `@MainActor` provider from a nonisolated registry. When a module or provider is marked `@MainActor`, the whole registry is generated as `@MainActor enum AppDependencies: @preconcurrency DependencyRegistry`, so register it from the main actor (for example in `App.init`) and resolve its main-actor dependencies there. The module's `init()` satisfies a nonisolated protocol requirement, so mark it `nonisolated`:

```swift
@MainActor
final class ScreenModule: TransientScope {
    nonisolated init() {}

    func viewModel(repository: UserRepository) -> HomeViewModel {
        HomeViewModel(repository: repository)
    }
}
```

Each `@MainActor` provider's factory also starts with `precondition(Thread.isMainThread, ...)`. The container runs factories on whichever thread resolves, so without the check a background `resolve` would silently build a main-actor object off the main thread. Other providers in the registry can still be resolved from any thread.

The generator only sees `@MainActor` written on the module or its providers. A module isolated another way (for example by `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) is already handled by that setting.

### Scopes

- **SingletonScope**: Dependencies are created once, during registration, and reused
- **LazySingletonScope**: Dependencies are created once, on first resolve, and reused
- **TransientScope**: New instance created each time

### Rules

1. Only computed properties (not stored properties) are considered
2. Only methods with return types are scanned (void methods are ignored)
3. All parameters without default values are treated as dependencies
4. Use `@Name("...")` on declarations, or a `/// @Name("...")` doc-comment line, to create named dependencies
5. Use `@Named("...")` on method parameters to inject named dependencies
6. A singleton or lazy singleton that depends on a transient dependency keeps a single instance of it forever, so the generator prints a `warning:` for it

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
                                 (falls back to ARROW_EXT_PATH, then
                                 <proj-root>/dependencies.generated.swift)
  --package-path <path>          Path to a Swift Package sources directory
                                 (can be specified multiple times; falls back to
                                 ARROW_PACKAGE_PATHS)
  --external-path <path>         Sources of dependencies provided by another registry;
                                 used for validation only (can be specified multiple
                                 times; falls back to ARROW_EXTERNAL_PATHS)
  --registry-name <name>         Name of the generated registry type
                                 (falls back to ARROW_REGISTRY_NAME, then
                                 <name>Dependencies)
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
