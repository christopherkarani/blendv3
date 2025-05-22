// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Blendv3",
    platforms: [.iOS(.v16)],
    dependencies: [
        // Stellar iOS SDK for blockchain interactions
        .package(url: "https://github.com/Soneso/stellar-ios-mac-sdk.git", from: "3.1.0"),
        
        // KeychainSwift for secure key storage
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "20.0.0")
    ],
    targets: [
        .target(
            name: "Blendv3",
            dependencies: [
                .product(name: "stellarsdk", package: "stellar-ios-mac-sdk"),
                .product(name: "KeychainSwift", package: "keychain-swift")
            ]
        )
    ]
)