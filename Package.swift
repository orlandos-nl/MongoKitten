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
        .library(
            name: "GridFS",
            targets: ["GridFS"]),
    ],
    dependencies: [
        // 💾
        .package(url: "https://github.com/OpenKitten/BSON.git", from: "6.0.0"),

        // 🚀
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.8.0"),
        
        // 🔑
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "1.1.1"),

        // 📚
        .package(url: "https://github.com/openkitten/NioDNS.git", .revision("66933d4febeac1b5b7a1ecb24388dbbab3025baa")),
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
            dependencies: ["BSON", "_MongoKittenCrypto", "NIO", "NIOOpenSSL", "NioDNS"]),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
    ]
)
