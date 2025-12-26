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
    .package(name: "ArrowGeneratorPlugin", path: "../../arrow-generator-plugin"),
    .package(name: "Arrow", path: "../../arrow"),
  ],
  targets: [
    .target(
      name: "Analytics",
      dependencies: [
        "Arrow"
      ]
    )

  ]
)
