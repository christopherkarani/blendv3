// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Blendv3",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BlendCore",
            targets: ["BlendCore"]
        ),
        .library(
            name: "BlendUI",
            targets: ["BlendUI"]
        )
    ],
    dependencies: [
        // Stellar SDK dependency
        .package(url: "https://github.com/Soneso/stellar-ios-mac-sdk", from: "2.5.0")
    ],
    targets: [
        // Core functionality target
        .target(
            name: "BlendCore",
            dependencies: [
                .product(name: "stellarsdk", package: "stellar-ios-mac-sdk")
            ],
            path: "Blendv3/Core"
        ),
        
        // UI components target
        .target(
            name: "BlendUI",
            dependencies: ["BlendCore"],
            path: "Blendv3/Views"
        ),
        
        // Test target
        .testTarget(
            name: "BlendCoreTests",
            dependencies: ["BlendCore"],
            path: "Blendv3Tests/Core"
        )
    ]
)