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
    ],
    targets: [
        .target(
            name: "_MongoKittenCrypto",
            dependencies: []
        ),
        .target(
            name: "GridFS",
            dependencies: ["BSON", "MongoKitten", "NIO"]),
        .testTarget(
            name: "MongoKittenTests",
            dependencies: ["MongoKitten"]),
    ]
)

#if swift(>=5.0)
package.dependencies.append(
     .package(url: "https://github.com/openkitten/NioDNS.git", .revision("3f9ed96afab3878d09737e18556110e528135099"))
)
package.targets.append(
    .target(
        name: "MongoKitten",
        dependencies: ["BSON", "_MongoKittenCrypto", "NIO", "NIOOpenSSL", "NioDNS"])
)
#else
package.targets.append(
    .target(
        name: "MongoKitten",
        dependencies: ["BSON", "_MongoKittenCrypto", "NIO", "NIOOpenSSL"])
)

#endif
