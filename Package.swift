import PackageDescription

var package = Package(
    name: "MongoKitten",
    targets: [
        Target(name: "MongoKitten")
        ],
    dependencies: [
        // For MongoDB Documents
        .Package(url: "https://github.com/OpenKitten/BSON.git", "4.1.0-beta"),

        // Authentication
        .Package(url: "https://github.com/OpenKitten/CryptoKitten.git", majorVersion: 0, minor: 1),
        
        // Provides sockets
        .Package(url: "https://github.com/vapor/socks.git", majorVersion: 1),

        // SSL
        .Package(url: "https://github.com/vapor/tls.git", majorVersion: 1),

        // Logging
        .Package(url: "https://github.com/OpenKitten/LogKitten.git", majorVersion: 0, minor: 3),
    ]
)
