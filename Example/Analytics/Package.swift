// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Analytics",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
  ],
  products: [
    .library(
      name: "Analytics",
      targets: ["Analytics"]
    )
  ],
  dependencies: [
    // Local checkout so the Example always builds against this repository's Arrow.
    .package(path: "../..")
  ],
  targets: [
    .target(
      name: "Analytics",
      dependencies: [
        .product(name: "Arrow", package: "arrow")
      ]
    )

  ]
)
