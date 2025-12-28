// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
// Requires: Swift 6.0+ (Xcode 16.0+)

import PackageDescription

// ⚠️ SYNC: Keep in sync with:
// - Sources/Constants/Constants.swift
// - arrow-generator-plugin/ArrowPlugin.swift
private let executableName = "arrow"

let package = Package(
  name: "ArrowGenerator",
  // Minimum platform: macOS 10.15 (Catalina, 2019) - Supports most developer machines
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .executable(name: executableName, targets: ["ArrowGenerator"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "602.0.0"),
    .package(url: "https://github.com/kylef/PathKit.git", exact: "1.0.1"),
    .package(url: "https://github.com/tuist/XcodeProj.git", exact: "9.7.1"),
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
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        "XcodeProj",
        "Constants",
      ]),
    .testTarget(
      name: "ArrowGeneratorCoreTests",
      dependencies: ["ArrowGeneratorCore"]),
  ]
)
