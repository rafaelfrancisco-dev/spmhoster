// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "spmhoster",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    // 💧 A server-side Swift web framework.
    .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
    // 🍃 An expressive, performant, and extensible templating language built for Swift.
    .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
    // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
  ],
  targets: [
    .executableTarget(
      name: "spmhoster",
      dependencies: [
        .product(name: "Leaf", package: "leaf"),
        .product(name: "Vapor", package: "vapor"),
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "spmhosterTests",
      dependencies: [
        .target(name: "spmhoster"),
        .product(name: "XCTVapor", package: "vapor"),
        .product(name: "VaporTesting", package: "vapor"),
      ],
      swiftSettings: swiftSettings
    ),
  ]
)

var swiftSettings: [SwiftSetting] {
  [
    .enableUpcomingFeature("ExistentialAny")
  ]
}
