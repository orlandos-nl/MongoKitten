// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
    name: "MongoKitten",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MongoKitten",
            targets: ["MongoKitten", "MongoClient"]),
        .library(
            name: "Meow",
            targets: ["Meow"]),
        .library(
            name: "MongoClient",
            targets: ["MongoClient"]),
        .library(
            name: "MongoCore",
            targets: ["MongoCore"]),
    ],
    dependencies: [
        // 💾
        .package(url: "https://github.com/OpenKitten/BSON.git", .revision("master/7.0")),
        // 🚀
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        
        // 🔑
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"),

        // 📚
        .package(url: "https://github.com/openkitten/NioDNS.git", .revision("master")),
    ],
    targets: [
        .target(
            name: "_MongoKittenCrypto",
            dependencies: []),
        .target(
            name: "MongoCore",
            dependencies: ["BSON", "_MongoKittenCrypto", "NIO"]),
        .target(
            name: "MongoClient",
            dependencies: ["MongoCore", "NIOSSL", "DNSClient"]),
        .target(
            name: "MongoKitten",
            dependencies: ["MongoClient"]),
        .target(
            name: "Meow",
            dependencies: ["MongoKitten"]),
        .testTarget(
            name: "MongoCoreTests",
            dependencies: ["MongoCore"]),
        //.testTarget(
        //    name: "MongoClientTests",
        //    dependencies: ["MongoClient"]),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
        .testTarget(
            name: "MeowTests",
            dependencies: ["Meow"]),
    ]
)
