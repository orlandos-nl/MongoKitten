// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
    name: "MongoKitten",
    platforms: [
        .macOS(.v10_14)
    ],
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
        // ✏️
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    
        // 📈
        .package(url: "https://github.com/apple/swift-metrics.git", from: "1.0.0"),
        
        // 💾
        .package(url: "https://github.com/OpenKitten/BSON.git", from: "7.0.0"),
        
        // 🚀
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),

        // 📚
        .package(url: "https://github.com/openkitten/NioDNS.git", .revision("master")),
        
        
    ],
    targets: [
        .target(
            name: "_MongoKittenCrypto",
            dependencies: []),
        .target(
            name: "MongoCore",
            dependencies: ["BSON", "_MongoKittenCrypto", "NIO", "Logging", "Metrics"]),
            .target(
                name: "MongoKittenCore",
                dependencies: ["MongoClient"]),
        .target(
            name: "MongoKitten",
            dependencies: ["MongoClient", "MongoKittenCore"]),
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

#if canImport(Network)
// 🔑
package.dependencies.append(.package(url: "https://github.com/joannis/swift-nio-transport-services.git", .revision("feature/udp-support")))
let transport: Target.Dependency = "NIOTransportServices"
package.platforms = [
    .macOS(.v10_14),
    .iOS(.v12),
]
#else
// 🔑
package.dependencies.append(.package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.0.0"))
let transport: Target.Dependency = "NIOSSL"
#endif

package.targets.append(
    .target(
        name: "MongoClient",
        dependencies: ["MongoCore", transport, "DNSClient"]
    )
)
