// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(Linux)
let ssl: Target.Dependency = "OpenSSL"
#else
let ssl: Target.Dependency = "AppleTLS"
#endif

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
        .package(url: "https://github.com/OpenKitten/BSON.git", from: "5.0.0"),
        
        // Sockets
        .package(url: "https://github.com/vapor/async.git", .revision("beta")),
        .package(url: "https://github.com/vapor/engine.git", .revision("beta")),
        .package(url: "https://github.com/vapor/crypto.git", .revision("beta")),
    ],
    targets: [
        .target(
            name: "ExtendedJSON",
            dependencies: ["BSON", "Crypto"]),
        .target(
            name: "MongoKitten",
            dependencies: ["BSON", "ExtendedJSON", "Async", "TLS", "TCP", "Crypto", ssl]),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
        ]
)
