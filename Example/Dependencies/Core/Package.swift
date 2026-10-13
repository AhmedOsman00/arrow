// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Core",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
  ],
  products: [
    .library(
      name: "Core",
      targets: ["Core"]
    )
  ],
  dependencies: [
    // Local checkout so the Example always builds against this repository's Arrow.
    .package(path: "../../..")
  ],
  targets: [
    .target(
      name: "Core",
      dependencies: [
        .product(name: "Arrow", package: "arrow")
      ]
    )
  ]
)
