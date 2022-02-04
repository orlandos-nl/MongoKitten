// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MongoKitten",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MongoKitten",
            targets: ["MongoKitten"]),
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
        // ✏️
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    
        // 📈
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0" ..< "3.0.0"),        
        
        // 💾
        .package(url: "https://github.com/orlandos-nl/BSON.git", .branch("master/8.0")),
//        .package(name: "BSON", path: "../BSON"),
        
        // 🚀
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),

        // 📚
        .package(url: "https://github.com/orlandos-nl/NioDNS.git", .branch("3.0")),
//        .package(name: "DNSClient", path: "../NioDNS"),
        
        // 🔑
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "_MongoKittenCrypto",
            dependencies: []),
        .target(
            name: "MongoCore",
            dependencies: [
                .product(name: "BSON", package: "BSON"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
            ]),
        .target(
            name: "MongoKittenCore",
            dependencies: ["MongoClient"]),
        .target(
            name: "MongoKitten",
            dependencies: ["MongoClient", "MongoKittenCore"]),
        .target(
            name: "Meow",
            dependencies: ["MongoKitten"]),
        .target(
            name: "MongoClient",
            dependencies: [
                "MongoCore",
                "_MongoKittenCrypto",
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "DNSClient", package: "NioDNS"),
            ]
        ),
        .testTarget(
            name: "MongoCoreTests",
            dependencies: ["MongoCore"]),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
        // TODO: Reimplement these tests
//        .testTarget(
//            name: "MeowTests",
//            dependencies: ["Meow"]),
    ]
)
