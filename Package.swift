// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
    name: "MongoKitten",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MongoKitten",
            targets: ["MongoKitten"]),
        .library(
            name: "GridFS",
            targets: ["GridFS"]),
    ],
    dependencies: [
        // 💾
        .package(url: "https://github.com/OpenKitten/BSON.git", .revision("master/7.0")),
        // 🚀
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        
        // 🔑
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),

        // 📚
        .package(url: "https://github.com/openkitten/NioDNS.git", .revision("4a31420564f371a74a1b6ec3a3cd60c72e04ef18")),
    ],
    targets: [
        .target(
            name: "_MongoKittenCrypto",
            dependencies: []
        ),
        .target(
            name: "GridFS",
            dependencies: ["BSON", "MongoKitten", "NIO"]),
        .target(
            name: "MongoKitten",
            dependencies: ["BSON", "_MongoKittenCrypto", "NIO", "NIOSSL", "NioDNS"]),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
    ]
)
