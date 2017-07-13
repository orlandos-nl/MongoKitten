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
        .package(url: "https://github.com/OpenKitten/BSON.git", .revision("29e51865ce352e83351932fe41c65ddc3254a447")),
        
        // For ExtendedJSON support
        .package(url: "https://github.com/OpenKitten/Cheetah.git", .revision("swift4")),
        
        // Authentication
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .revision("swift4")),
        
        // Asynchronous behaviour
        .package(url: "https://github.com/OpenKitten/Schrodinger.git", .revision("framework")),
        ],
    targets: [
        .target(
            name: "GeoJSON",
            dependencies: ["BSON", "Cheetah"]),
        .target(
            name: "ExtendedJSON",
            dependencies: ["BSON", "Cheetah"]),
        .target(
            name: "MongoKitten",
            dependencies: ["BSON", "Cheetah", "GeoJSON", "ExtendedJSON", "CryptoSwift", "Schrodinger"]),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
        ]
)

// Provides Sockets + SSL
#if !os(macOS) && !os(iOS)
    package.dependencies.append(.package(url: "https://github.com/OpenKitten/KittenCTLS.git", majorVersion: 1))
    package.targets.append(.target(name: "MongoSocket", dependencies: ["KittenCTLS"]))
#else
    package.targets.append(.target(name: "MongoSocket", dependencies: []))
#endif
