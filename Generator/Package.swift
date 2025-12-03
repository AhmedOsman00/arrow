// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// ⚠️ SYNC: Keep in sync with:
// - Sources/Constants/Constants.swift
// - Plugins/ArrowPlugin/ArrowPlugin.swift
private let executableName = "arrow"

let package = Package(
    name: "ArrowGenerator",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: executableName, targets: ["ArrowGenerator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/console-kit.git", exact: "4.15.2"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "602.0.0"),
        .package(url: "https://github.com/kylef/PathKit.git", exact: "1.0.1"),
        .package(url: "https://github.com/tuist/XcodeProj.git", exact: "9.6.0")
    ],
    targets: [
        .executableTarget(
            name: "ArrowGenerator",
            dependencies: ["ArrowGeneratorCore"]),
        .target(name: "Constants"),
        .target(
            name: "ArrowGeneratorCore",
            dependencies: [
                "PathKit",
                .product(name: "ConsoleKit", package: "console-kit"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                "XcodeProj",
                "Constants"
            ]),
        .testTarget(
            name: "ArrowGeneratorCoreTests",
            dependencies: ["ArrowGeneratorCore"])
    ]
)
