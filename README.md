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
    .package(url: "https://github.com/AhmedOsman00/Arrow.git", from: "1.0.0")
]
```

Or in Xcode: **File > Add Package Dependencies** → `https://github.com/AhmedOsman00/Arrow.git`

## Quick Start

Arrow uses **modules** to organize dependencies. The [Arrow Generator](https://github.com/AhmedOsman00/arrow-generator) automatically creates all registration code for you.

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

Run the generator to create registration code automatically:

```bash
# For Swift Packages
swift package plugin arrow-generator

# For Xcode Projects
arrow generate --project-path YourApp.xcodeproj
```

See the [Arrow Generator documentation](https://github.com/AhmedOsman00/arrow-generator) for installation and detailed usage.

### 3. Register at App Startup

Call the generated registration method:

```swift
@main
struct MyApp: App {
    init() {
        Container.shared.register()
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

**TransientScope** - New instance on each resolve:

```swift
final class ViewModelModule: TransientScope {
    func detailViewModel() -> DetailViewModel {
        DetailViewModel()  // Fresh instance each time
    }
}
```

## Module Rules

1. Modules must conform to `SingletonScope` or `TransientScope`
2. Modules must have a no-parameter `init()`
3. Only computed properties and functions with return types are scanned
4. Function parameters without defaults are treated as injectable dependencies
5. Use `@Named("...")` to reference named dependencies in parameters
6. Use `@Name("...")` macro to mark providers that create named dependencies

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

## Example Project

See the [Example](./Example) directory for a complete iOS app demonstrating:
- Multiple modules with different scopes
- Named dependencies
- SwiftUI integration
- Analytics integration pattern

## Requirements

- **Swift**: 6.0+
- **Xcode**: 16.0+
- **Platforms**: iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, macCatalyst 13+
- **Code Generator**: [Arrow Generator](https://github.com/AhmedOsman00/arrow-generator) CLI or SPM Plugin

## Related Projects

- [Arrow Generator](https://github.com/AhmedOsman00/arrow-generator) - Code generation CLI tool
- [Arrow Generator Plugin](https://github.com/AhmedOsman00/arrow-generator-plugin) - SPM plugin wrapper

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
