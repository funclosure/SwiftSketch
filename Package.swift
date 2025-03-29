// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftSketch",
    platforms: [.macOS(.v14)], // CLI runs on macOS
    products: [
        .executable(name: "swift-sketch", targets: ["SwiftSketch"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftSketch",
            dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")]
        )
    ]
)
