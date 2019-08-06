// swift-tools-version:4.0
import PackageDescription

var package = Package(
    name: "MongoKitten",
    products: [
        .library(name: "MongoKitten", targets: ["MongoKitten"]),
        .library(name: "GeoJSON", targets: ["GeoJSON"]),
        .library(name: "ExtendedJSON", targets: ["ExtendedJSON"]),
    ],
    dependencies: [
        // For MongoDB Documents
        .package(url: "https://github.com/OpenKitten/BSON.git", .revision("5.2.7-swift5")),
        
        // For ExtendedJSON support
        .package(url: "https://github.com/OpenKitten/Cheetah.git", .revision("2.0.3-swift5")),

        // Authentication
        .package(url: "https://github.com/OpenKitten/CryptoKitten.git", .revision("0.2.4-swift5")),

        // Asynchronous behaviour
        .package(url: "https://github.com/OpenKitten/Schrodinger.git", .revision("1.0.3-swift5")),
    ],
    targets: [
        .target(name: "GeoJSON", dependencies: ["BSON"]),
        .target(name: "ExtendedJSON", dependencies: ["BSON", "Cheetah", "CryptoKitten"]),
        .target(name: "MongoKitten", dependencies: ["BSON", "CryptoKitten", "Schrodinger", "GeoJSON", "MongoSocket", "ExtendedJSON"]),
        .testTarget(name: "MongoKittenTests", dependencies: ["MongoKitten"])
    ]
)

// Provides Sockets + SSL
#if !os(macOS) && !os(iOS)
package.dependencies.append(.package(url: "https://github.com/apple/swift-nio-ssl-support.git", from: "1.0.0"))
package.targets.append(.target(name: "CMongoSocket"))
package.targets.append(.target(name: "MongoSocket", dependencies: ["CMongoSocket"]))
#else
package.targets.append(.target(name: "MongoSocket"))
#endif
