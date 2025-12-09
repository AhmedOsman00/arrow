# Modularization Guide

This guide explains how to use Arrow Generator with modularized projects where your codebase is split into multiple modules (Swift packages, frameworks, or targets).

## Overview

In a modularized architecture, your app is divided into independent modules, each with its own dependencies. Arrow Generator needs to generate dependency registration code for each module separately.

**Key Concept**: Each module gets its own `dependencies.generated.swift` file with a dedicated registration method (e.g., `registerNetworking()`, `registerFeatureAuth()`, `registerApp()`).

## Project Structures

Arrow Generator supports two common modularization approaches:

### 1. Xcode Project with Multiple Targets/Frameworks

```
MyApp/
├── MyApp.xcodeproj
├── App/                      # Main app target
│   └── dependencies.generated.swift
├── Networking/               # Framework target
│   └── dependencies.generated.swift
└── FeatureAuth/             # Framework target
    └── dependencies.generated.swift
```

### 2. Swift Packages (Local or External)

```
MyApp/
├── MyApp.xcodeproj          # Main app
├── Packages/
│   ├── Networking/          # Local package
│   │   ├── Package.swift
│   │   └── Sources/
│   │       └── dependencies.generated.swift
│   ├── FeatureAuth/         # Local package
│   │   ├── Package.swift
│   │   └── Sources/
│   │       └── dependencies.generated.swift
│   └── Analytics/           # Local package
│       ├── Package.swift
│       └── Sources/
│           └── dependencies.generated.swift
└── App/
    └── dependencies.generated.swift
```

### 3. Hybrid: Xcode + Local Packages

```
MyWorkspace/
├── MyApp/                   # Xcode project
│   ├── MyApp.xcodeproj
│   └── App/
│       └── dependencies.generated.swift
└── Packages/                # Shared packages
    ├── Core/
    │   └── Package.swift
    ├── Networking/
    │   └── Package.swift
    └── Features/
        ├── FeatureAuth/
        │   └── Package.swift
        └── FeatureProfile/
            └── Package.swift
```

## Batch Generation Script

The `scripts/generate-all.sh` script automates dependency generation across multiple modules. It's designed to be used in Xcode Build Phases.

### Script Features

- **Auto-detects current Xcode project**: Uses `$PROJECT_FILE_PATH` and `$TARGET_NAME` from Xcode build phase environment
- **Supports Swift Packages**: Generates for listed Swift packages using the plugin
- **Wildcard patterns**: Use `/**` to find all packages under a directory

### Configuration

Copy the script content from `scripts/generate-all.sh` and configure it:

```bash
#!/bin/bash

# Path to arrow generator binary (adjust to your setup)
GENERATOR_BIN="$SRCROOT/arrow-generator/bin/arrow"

# List your Swift Packages here
PACKAGES=(
  "$SRCROOT/../Networking"           # Single package
  "$SRCROOT/../Packages/Core/**"     # All packages under Core/
  "$SRCROOT/../Packages/Features/**" # All packages under Features/
)
```

### Xcode Build Phase Integration

**Step 1: Add Build Phase**

1. Open your Xcode project
2. Select your target
3. Go to **Build Phases** tab
4. Click **+** → **New Run Script Phase**
5. Name it "Generate Dependencies"

**Step 2: Add Script**

Paste the entire content from `scripts/generate-all.sh`.

**Step 3: Configure**

Update the `GENERATOR_BIN` and `PACKAGES` array to match your project structure.

**Step 4: Position**

Drag the "Generate Dependencies" phase **before** "Compile Sources" phase.

### Wildcard Pattern Examples

```bash
PACKAGES=(
  # Exact paths
  "$SRCROOT/../Networking"
  "$SRCROOT/../Analytics"

  # Find all packages under a directory
  "$SRCROOT/../Modules/**"          # Finds: Modules/A, Modules/B, Modules/C

  # Nested packages
  "$SRCROOT/../Features/**"         # Finds: Features/Auth, Features/Auth/Submodule, Features/Profile

  # Multiple directories
  "$SRCROOT/../Core/**"
  "$SRCROOT/../Services/**"
  "$SRCROOT/../Features/**"
)
```

The script uses `find` to locate all `Package.swift` files under the base path and runs the Arrow Generator plugin for each package.

## Manual Generation Per Module

If you prefer manual control or need to generate for specific modules:

### For Xcode Targets/Frameworks

```bash
# Main app target
arrow generate \
  --xcode-proj-path ./MyApp.xcodeproj \
  --target-name MyApp

# Framework target
arrow generate \
  --xcode-proj-path ./MyApp.xcodeproj \
  --target-name Networking

# Another framework
arrow generate \
  --xcode-proj-path ./MyApp.xcodeproj \
  --target-name FeatureAuth
```

### For Swift Packages

**Using the Plugin (Recommended):**

```bash
cd Packages/Networking
swift package plugin arrow-generator --allow-writing-to-package-directory

cd ../FeatureAuth
swift package plugin arrow-generator --allow-writing-to-package-directory

cd ../Analytics
swift package plugin arrow-generator --allow-writing-to-package-directory
```

**Using the CLI:**

```bash
arrow generate \
  --is-package \
  --package-name Networking \
  --package-sources-path ./Packages/Networking/Sources

arrow generate \
  --is-package \
  --package-name FeatureAuth \
  --package-sources-path ./Packages/FeatureAuth/Sources
```

## Container Registration Order

When using multiple modules, register them in your app's main entry point in dependency order (low-level to high-level):

```swift
import Arrow
import Networking
import FeatureAuth
import FeatureProfile
import Analytics

@main
struct MyApp: App {
    init() {
        let container = Container.shared

        // Register in dependency order
        container.registerNetworking()      // Low-level: Network layer
        container.registerAnalytics()       // Low-level: Analytics
        container.registerFeatureAuth()     // Mid-level: Uses Networking
        container.registerFeatureProfile()  // Mid-level: Uses Networking + Auth
        container.registerMyApp()           // Top-level: Main app dependencies

        // Now resolve and use
        let viewModel: HomeViewModel = container.resolved()
    }

    var body: some Scene {
        // ...
    }
}
```

## Best Practices

### 1. One Generated File Per Module

Each module should have exactly one `dependencies.generated.swift` file. Never manually combine multiple modules into one file.

### 2. Clear Module Boundaries

Ensure each module has clear responsibilities:

```
Networking/           # HTTP client, API services
  └── NetworkingModule: SingletonScope

FeatureAuth/         # Authentication logic
  └── AuthModule: SingletonScope

FeatureProfile/      # User profile feature
  └── ProfileModule: SingletonScope

App/                 # App-level coordination
  └── AppModule: SingletonScope
```

### 3. Avoid Circular Module Dependencies

Design your module graph as a DAG (Directed Acyclic Graph):

**Good:**
```
App → FeatureAuth → Networking
App → Analytics
```

**Bad:**
```
App ↔ FeatureAuth  (circular!)
```

If Arrow Generator detects circular dependencies **within** a module, it will report an error. Ensure your inter-module dependencies also don't create cycles.

### 4. Use Named Dependencies for Module-Specific Instances

When multiple modules provide the same type:

```swift
// In Networking module
final class NetworkingModule: SingletonScope {
    @Named("Production")
    var prodAPI: APIClient {
        APIClient(baseURL: "https://api.production.com")
    }

    @Named("Staging")
    var stagingAPI: APIClient {
        APIClient(baseURL: "https://api.staging.com")
    }
}

// In FeatureAuth module
final class AuthModule: SingletonScope {
    func authService(@Named("Production") apiClient: APIClient) -> AuthService {
        AuthService(apiClient: apiClient)
    }
}
```

### 5. Generate Before Compilation

Always ensure dependency generation happens **before** compilation:

- In Xcode: Place "Generate Dependencies" build phase before "Compile Sources"
- In CI/CD: Run generation scripts before `xcodebuild` or `swift build`

### 6. Version Control

**Do commit** `dependencies.generated.swift` files to version control:
- Ensures all team members have the same generated code
- Prevents build failures if generator isn't installed
- Makes code review easier

Add this to your `.gitignore` to exclude the generator binary if building from source:

```gitignore
# Don't commit the built binary
bin/arrow

# Do commit generated dependency files
!**/dependencies.generated.swift
```

## Troubleshooting

### Issue: "Dependency not found" across modules

**Cause**: Module registration order is incorrect, or a module isn't registered.

**Solution**: Ensure you register modules in dependency order:

```swift
container.registerModuleA()  // Provides Foo
container.registerModuleB()  // Needs Foo - must come after ModuleA
```

### Issue: Wildcard `/**` not finding packages

**Cause**: The base path doesn't exist or packages are in unexpected locations.

**Solution**: Verify paths and run the script with `set -x` for debugging:

```bash
#!/bin/bash
set -x  # Enable debug output

# ... rest of script
```

### Issue: Build phase script fails silently

**Cause**: Script errors aren't visible in Xcode build output.

**Solution**: Add explicit error handling:

```bash
#!/bin/bash
set -e  # Exit on error

# Your script here

if [ $? -ne 0 ]; then
  echo "error: Arrow Generator failed"
  exit 1
fi
```

### Issue: Duplicate dependencies across modules

**Cause**: Same dependency is defined in multiple modules.

**Solution**:
- Use `@Named("...")` to differentiate them
- Or consolidate into a single shared module
- Or keep them separate if they truly have different configurations

## Example: Complete Setup

Here's a full example for a typical modularized app:

### Project Structure

```
MyApp/
├── MyApp.xcodeproj
├── App/
│   ├── MyApp.swift
│   ├── AppModule.swift
│   └── dependencies.generated.swift
└── Packages/
    ├── Networking/
    │   ├── Package.swift
    │   └── Sources/
    │       ├── NetworkingModule.swift
    │       └── dependencies.generated.swift
    └── Features/
        ├── Auth/
        │   ├── Package.swift
        │   └── Sources/
        │       ├── AuthModule.swift
        │       └── dependencies.generated.swift
        └── Profile/
            ├── Package.swift
            └── Sources/
                ├── ProfileModule.swift
                └── dependencies.generated.swift
```

### Xcode Build Phase Script

```bash
#!/bin/bash

GENERATOR_BIN="/usr/local/bin/arrow"

PACKAGES=(
  "$SRCROOT/../Packages/Networking"
  "$SRCROOT/../Packages/Features/**"
)

# Generate for current Xcode target (App)
if [[ -n "$PROJECT_FILE_PATH" && -n "$TARGET_NAME" ]]; then
  echo "🔨 Generating dependencies for Xcode project: $TARGET_NAME"
  "$GENERATOR_BIN" generate --xcode-proj-path "$PROJECT_FILE_PATH" --target-name "$TARGET_NAME"
fi

# Generate for Swift Packages
for package_pattern in "${PACKAGES[@]}"; do
  if [[ "$package_pattern" == *"/**" ]]; then
    base_path="${package_pattern%/**}"
    if [[ -d "$base_path" ]]; then
      echo "🔍 Searching for packages in: $base_path"
      while IFS= read -r package; do
        echo "📦 Generating: $package"
        (cd "$package" && swift package plugin --allow-writing-to-package-directory arrow-generator)
      done < <(find "$base_path" -type f -name "Package.swift" -not -path "*/.*" -exec dirname {} \;)
    fi
  else
    if [[ -d "$package_pattern" && -f "$package_pattern/Package.swift" ]]; then
      echo "📦 Generating: $package_pattern"
      (cd "$package_pattern" && swift package plugin --allow-writing-to-package-directory arrow-generator)
    fi
  fi
done

echo "✅ Done!"
```

### App Registration

```swift
// App/MyApp.swift
import Arrow
import Networking
import FeatureAuth
import FeatureProfile

@main
struct MyApp: App {
    init() {
        setupDependencies()
    }

    private func setupDependencies() {
        let container = Container.shared

        // Register in dependency order
        container.registerNetworking()
        container.registerFeatureAuth()
        container.registerFeatureProfile()
        container.registerMyApp()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Additional Resources

- [Arrow Framework Documentation](https://github.com/AhmedOsman00/Arrow)
- [Arrow Generator Plugin](https://github.com/AhmedOsman00/arrow-generator-plugin)
- [Contributing Guide](CONTRIBUTING.md)
