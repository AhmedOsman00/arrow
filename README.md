# Arrow

A lightweight, type-safe dependency injection framework for Swift that eliminates boilerplate through automatic code generation.

## Features

- **Zero Boilerplate**: Automatic dependency registration via code generation
- **Type-Safe**: Compile-time type checking for all dependencies
- **Simple API**: Define dependencies using regular Swift methods and properties
- **Lifecycle Scopes**: Support for singleton and transient dependencies
- **Named Dependencies**: Multiple implementations of the same type
- **Swift Package Manager**: First-class SPM support
- **Thread-Safe**: Lock-protected registration and resolution

## Installation

### Swift Package Manager

Add Arrow to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/AhmedOsman00/Arrow.git", from: "2.1.0")
]
```

Or in Xcode: **File > Add Package Dependencies** → `https://github.com/AhmedOsman00/Arrow.git`

## Quick Start

Arrow uses **modules** to organize dependencies. The [Arrow Generator](Generator/README.md) automatically creates all registration code for you.

### 1. Define a Module

Create a module conforming to a scope protocol:

```swift
import Arrow

final class AppModule: SingletonScope {
    var apiClient: APIClient {
        APIClient(baseURL: "https://api.example.com")
    }

    func userRepository(apiClient: APIClient) -> UserRepository {
        UserRepository(apiClient: apiClient)
    }

    func userViewModel(repository: UserRepository) -> UserViewModel {
        UserViewModel(repository: repository)
    }
}
```

### 2. Generate Registration Code

Install the [Arrow Generator](Generator/README.md). It's released together with Arrow, so use the same version of both:

```bash
brew install --cask AhmedOsman00/tap/arrow
```

**Xcode app targets** run it from a build phase, so the registry is regenerated on every build:

1. Create an empty `dependencies.generated.swift` in the project root and add it to your target.
2. In the target's Build Settings, set **User Script Sandboxing** (`ENABLE_USER_SCRIPT_SANDBOXING`) to **No**, since the generator has to read all your Swift files.
3. Add a Run Script phase above **Compile Sources**, and uncheck **Based on dependency analysis**:

   ```bash
   export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

   if command -v arrow >/dev/null; then
     arrow generate
   else
     echo "error: Arrow Generator is not installed. Run: brew install --cask AhmedOsman00/tap/arrow"
     exit 1
   fi
   ```

The script needs no arguments: it reads Xcode's build settings. Configure it per target with `ARROW_*` build settings, for example `ARROW_EXTERNAL_PATHS` for dependencies provided by another registry. See [Running From Xcode](Generator/README.md#running-from-xcode) for every setting.

**Swift packages** run it from the command line, or a `Makefile` target:

```bash
arrow generate --is-package --package-path Sources/YourPackage
```

### 3. Register at App Startup

The generator creates a `DependencyRegistry` per app target or package (for example `AppDependencies`). Register them at startup, passing registries before the ones that depend on them:

```swift
@main
struct MyApp: App {
    init() {
        Container.shared.register(
            CoreDependencies.self,   // from a package
            AppDependencies.self     // from the app target
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 4. Resolve Dependencies

**Recommended: Initializer Injection**

Use constructor injection (with the help of the generator) to make dependencies explicit and testable:

```swift
class MyViewController: UIViewController {
    private let viewModel: UserViewModel

    init(viewModel: UserViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

**Alternative: Property Wrappers**

Use sparingly when initializer injection isn't practical:

```swift
class MyViewController: UIViewController {
    @Inject var viewModel: UserViewModel        // Required dependency
    @Autowire var optionalService: Service?     // Optional dependency
}
```

## Property Wrappers

- **@Inject** - Required dependency (crashes if not found)
- **@Autowire** - Optional dependency (returns nil if not found)
- **@Presenter**, **@ViewModel** - Aliases for @Inject

## Dependency Scopes

**SingletonScope** - Created once and cached:

```swift
final class AppModule: SingletonScope {
    var database: Database {
        Database()  // Singleton instance
    }
}
```

**LazySingletonScope** - Created once, on first resolve, then cached. Use it for expensive dependencies that aren't needed at launch:

```swift
final class StorageModule: LazySingletonScope {
    var database: Database {
        Database()  // Created on first resolve
    }
}
```

**TransientScope** - New instance on each resolve:

```swift
final class ViewModelModule: TransientScope {
    func detailViewModel() -> DetailViewModel {
        DetailViewModel()  // Fresh instance each time
    }
}
```

## Module Rules

1. Modules must conform to `SingletonScope`, `LazySingletonScope` or `TransientScope`
2. Modules must have a no-parameter `init()`
3. Only computed properties and functions with return types are scanned
4. Function parameters without defaults are treated as injectable dependencies
5. Use `@Named("...")` to reference named dependencies in parameters
6. Use `@Name("...")` macro to mark providers that create named dependencies. It lives in the opt-in
   `ArrowMacros` product (`import ArrowMacros`), so only targets that use it build swift-syntax. To skip the
   macro entirely, write it as a doc-comment marker on its own line: `/// @Name("...")`
7. Optional parameters (`cache: Cache?`) are resolved with `tryResolve`, so they're `nil` when nothing provides them
8. A `@MainActor` module gets a `@MainActor` registry; give the module a `nonisolated init()`. Resolve its
   dependencies on the main thread: their factories check and crash otherwise

## Manual Registration

For advanced use cases, you can manually register dependencies:

```swift
// Register
Container.shared.register(APIClient.self, objectScope: .singleton) { resolver in
    APIClient(baseURL: "https://api.example.com")
}

Container.shared.register(UserRepository.self, objectScope: .singleton) { resolver in
    UserRepository(apiClient: resolver.resolve(APIClient.self))
}

// Resolve
let repository = Container.shared.resolve(UserRepository.self)
```

Resolution is thread-safe. A lazy singleton whose factory ends up resolving itself crashes with a "Circular dependency" message instead of deadlocking.

## Testing With an Isolated Container

`Container.shared` is global. Tests can create their own container instead, so they don't share state or need `reset()`:

```swift
let container = Container()
container.register(AppDependencies.self)
container.register(APIClient.self, objectScope: .singleton) { _ in MockAPIClient() }

// Property wrappers resolve from `Container.shared` unless given a container
@Inject(container: container) var repository: UserRepository
```

## Example Project

See the [Example](./Example) directory for a complete iOS app demonstrating:
- Multiple modules with different scopes, including a lazy singleton
- A registry per package (`CoreDependencies`, `AnalyticsDependencies`) plus one for the app
- Named dependencies
- SwiftUI integration
- Analytics integration pattern

## Requirements

- **Swift**: 6.0+
- **Xcode**: 16.0+
- **Platforms**: iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+
- **Code Generator**: [Arrow Generator](Generator/README.md) CLI, at the same version as Arrow

## Repository Layout

This repository holds both halves of Arrow, released together under one version:

- The **Arrow library** at the root, which is what Swift Package Manager builds
- The **[Arrow Generator](Generator/README.md)** in `Generator/`, released as a binary through Homebrew
- **`Compatibility/`**, which CI uses to build the generator's output against the library on every PR

Run `make bootstrap` once, then `make test` and `make lint` to check both packages.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
