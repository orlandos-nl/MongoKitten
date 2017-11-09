// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
    name: "MongoKitten",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MongoKitten",
            targets: ["MongoKitten"]),
    ],
    dependencies: [
        // For MongoDB Documents
        .package(url: "https://github.com/OpenKitten/BSON.git", .revision("master/6.0")),
        
        // Asynchronous behaviour
        .package(url: "https://github.com/vapor/vapor.git", .revision("1e5658064b5be04405373dd2bb1a820c3ecc1802")),
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
