import PackageDescription

var package = Package(
    name: "MongoKitten",
    targets: [
        Target(name: "GeoJSON"),
        Target(name: "MongoSocket"),
        Target(name: "ExtendedJSON"),
        Target(name: "MongoKitten", dependencies: ["GeoJSON", "MongoSocket"])
        ],
    dependencies: [
        // Core protocol conformance
        .Package(url: "https://github.com/OpenKitten/KittenCore.git", majorVersion: 0),

        // For MongoDB Documents
        .Package(url: "https://github.com/OpenKitten/BSON.git", "5.0.0-obbut2"),
        
        // For ExtendedJSON support
        .Package(url: "https://github.com/OpenKitten/Cheetah.git", majorVersion: 0, minor: 2),

        // Authentication
        .Package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", Version(0,6,7)),

        // Provides Sockets + SSL
        .Package(url: "https://github.com/vapor/tls.git", majorVersion: 1),

        // Logging
        .Package(url: "https://github.com/OpenKitten/LogKitten.git", majorVersion: 0, minor: 3),
    ]
)
