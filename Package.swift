// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "Arrow",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
  ],
  products: [
    .library(name: "Arrow", targets: ["Arrow"]),
    // Opt-in: `@Name` is a macro, so this product builds swift-syntax. Arrow itself doesn't.
    .library(name: "ArrowMacros", targets: ["ArrowMacros"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"700.0.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),
  ],
  targets: [
    .target(name: "Arrow"),
    .target(
      name: "ArrowMacros",
      dependencies: [
        "Macros"
      ]),
    .macro(
      name: "Macros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "ArrowTests",
      dependencies: [
        "Arrow",
        "Macros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]),
  ]
)
