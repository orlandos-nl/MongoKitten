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
        .package(url: "file:///Users/joannisorlandos/Documents/OpenKitten/BSON/", .revision("framework")),
        
        // Asynchronous behaviour
        .package(url: "file:///Users/joannisorlandos/Documents/Vapor/vapor/", .revision("tls")),
        ],
    targets: [
        .target(
            name: "ExtendedJSON",
            dependencies: ["BSON"]),
        .target(
            name: "MongoKitten",
            dependencies: ["BSON", "ExtendedJSON", "Async", "TLS", "TCP", "Crypto"]),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
        ]
)
