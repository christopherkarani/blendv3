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
        .executable(
            name: "BlendApp",
            targets: ["BlendApp"]
        ),
        .library(
            name: "BlendCore",
            targets: ["BlendCore"]
        )
    ],
    dependencies: [
        // Stellar SDK dependency
        .package(url: "https://github.com/Soneso/stellar-ios-mac-sdk", from: "2.5.0")
    ],
    targets: [
        // Main executable target
        .executableTarget(
            name: "BlendApp",
            dependencies: [
                "BlendCore",
                .product(name: "stellarsdk", package: "stellar-ios-mac-sdk")
            ],
            path: "Blendv3",
            sources: ["BlendApp.swift"]
        ),
        
        // Core functionality target
        .target(
            name: "BlendCore",
            dependencies: [
                .product(name: "stellarsdk", package: "stellar-ios-mac-sdk")
            ],
            path: "Blendv3/Core"
        ),
        
        // Test target
        .testTarget(
            name: "BlendCoreTests",
            dependencies: ["BlendCore"],
            path: "Blendv3Tests/Core"
        )
    ]
)