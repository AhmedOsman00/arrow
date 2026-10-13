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
    .package(url: "https://github.com/AhmedOsman00/arrow.git", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "Core",
      dependencies: [
        .product(name: "Arrow", package: "Arrow")
      ]
    )
  ]
)
