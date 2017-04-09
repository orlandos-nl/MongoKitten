import PackageDescription

var package = Package(
    name: "MongoKitten",
    targets: [
        Target(name: "GeoJSON"),
        Target(name: "MongoSocket"),
        Target(name: "ExtendedJSON"),
        Target(name: "MongoKitten", dependencies: ["GeoJSON", "MongoSocket", "ExtendedJSON"])
        ],
    dependencies: [
        // For MongoDB Documents
        .Package(url: "https://github.com/OpenKitten/BSON.git", majorVersion: 5),
        
        // For ExtendedJSON support
        .Package(url: "https://github.com/OpenKitten/Cheetah.git", majorVersion: 1),

        // Authentication
        .Package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", Version(0,6,7)),

        // Provides Sockets + SSL
        .Package(url: "https://github.com/vapor/tls.git", majorVersion: 1),
        
        // Asynchronous behaviour
        .Package(url: "https://github.com/OpenKitten/Schrodinger.git", majorVersion: 1),
    ]
)
