// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
    name: "MongoKitten",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MongoKitten",
            targets: ["MongoKitten", "ExtendedJSON"]),
    ],
    dependencies: [
        // For MongoDB Documents
        .package(url: "https://github.com/OpenKitten/BSON.git", .revision("framework")),
        
        // For ExtendedJSON support
        .package(url: "https://github.com/OpenKitten/Cheetah.git", from: "2.0.0"),
        
        // Authentication
        .package(url: "https://github.com/OpenKitten/CryptoKitten.git", from: "0.2.1"),
        
        // Asynchronous behaviour
        .package(url: "https://github.com/OpenKitten/Schrodinger.git", .revision("framework")),
        ],
    targets: [
        .target(
            name: "GeoJSON",
            dependencies: ["BSON", "Cheetah"]),
        .target(
            name: "ExtendedJSON",
            dependencies: ["BSON", "Cheetah", "CryptoKitten"]),
        .target(
            name: "MongoKitten",
            dependencies: ["BSON", "Cheetah", "GeoJSON", "ExtendedJSON", "CryptoKitten", "Schrodinger", "MongoSocket"]),
        .target(name: "MongoSocket", dependencies: []),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
        ]
)

// Provides Sockets + SSL
#if !os(macOS) && !os(iOS)
    package.dependencies.append(.package(url: "https://github.com/OpenKitten/KittenCTLS.git", from: Version(1, 0, 0)))
#endif
