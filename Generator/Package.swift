// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Arrow",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "arrow", targets: ["Arrow"]),
        .plugin(
            name: "ArrowPlugin",
            targets: ["ArrowPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/console-kit.git", from: "4.5.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "600.0.1"),
        .package(url: "https://github.com/kylef/PathKit.git", exact: "1.0.1"),
        .package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.8.0"))
    ],
    targets: [
        .executableTarget(
            name: "Arrow",
            dependencies: ["Script"]),
        .plugin(
            name: "ArrowPlugin",
            capability: .buildTool()
        ),
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
