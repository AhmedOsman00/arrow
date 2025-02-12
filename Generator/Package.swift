// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Arrow",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // SPM won't generate .swiftmodule for a target directly used by a product,
        // hence it can't be imported by tests. Executable target can't be imported too.
        .executable(name: "arrow", targets: ["Arrow"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.5.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", .exact("600.0.1")),
        // PathKit needs to be exact to avoid a SwiftPM bug where dependency resolution takes a very long time.
        .package(url: "https://github.com/kylef/PathKit.git", .exact("1.0.1")),
        .package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.8.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "Arrow",
            dependencies: ["Script"]),
        .target(
            name: "Script",
            dependencies: [
                "PathKit",
                .product(name: "ConsoleKit", package: "console-kit"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                "XcodeProj"
            ]),
        .testTarget(
            name: "ScriptTests",
            dependencies: ["Script"])
    ]
)
