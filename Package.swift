// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LessBar",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LessBar", targets: ["LessBar"])],
    targets: [
        .target(name: "NativeVisibility", publicHeadersPath: "include", cSettings: [.define("HIDDENBAR_NATIVE_VISIBILITY", to: "1")]),
        .target(name: "NativePreferences", publicHeadersPath: "include"),
        .executableTarget(name: "LessBar", dependencies: ["NativePreferences", "NativeVisibility"], resources: [.process("Resources")]),
        .testTarget(name: "LessBarTests", dependencies: ["LessBar"])
    ]
)
