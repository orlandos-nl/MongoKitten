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
        // For MongoDB Documents
        .Package(url: "https://github.com/OpenKitten/BSON.git", Version(5,0,0, prereleaseIdentifiers: ["alpha", "2"])),
        
        // For ExtendedJSON support
        .Package(url: "https://github.com/OpenKitten/Cheetah.git", majorVersion: 0, minor: 3),

        // Authentication
        .Package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", Version(0,6,7)),

        // Provides Sockets + SSL
        .Package(url: "https://github.com/vapor/tls.git", Version(2,0,0, prereleaseIdentifiers: ["beta"])),
        
        // Asynchronous behaviour
        .Package(url: "https://github.com/OpenKitten/Schrodinger.git", majorVersion: 0, minor: 1),
    ]
)
