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
    .package(url: "https://github.com/AhmedOsman00/arrow.git", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "Analytics",
      dependencies: [
        .product(name: "Arrow", package: "Arrow")
      ]
    )

  ]
)
