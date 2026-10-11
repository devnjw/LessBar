// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LessBar",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LessBar", targets: ["LessBar"])],
    targets: [
        .executableTarget(name: "LessBar", resources: [.process("Resources")]),
        .testTarget(name: "LessBarTests", dependencies: ["LessBar"])
    ]
)
