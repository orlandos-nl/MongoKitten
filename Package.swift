import PackageDescription

var package = Package(
    name: "MongoKitten",
    targets: [
        Target(name: "MongoKitten", dependencies: [
            "MongoMD5",
            "MongoSCRAM",
            "MongoSHA1"
            ]),
        Target(name: "MongoMD5", dependencies: ["MongoCryptoEssentials"]),
        Target(name: "MongoSCRAM", dependencies: ["MongoPBKDF2"]),
        Target(name: "MongoPBKDF2", dependencies: ["MongoHMAC"]),
        Target(name: "MongoHMAC", dependencies: ["MongoCryptoEssentials"]),
        Target(name: "MongoSHA1", dependencies: ["MongoCryptoEssentials"]),
        Target(name: "MongoCryptoEssentials")
        ],
    dependencies: [
        // For MongoDB Documents
        .Package(url: "https://github.com/OpenKitten/BSON.git", majorVersion: 3, minor: 7),
        
        // Provides sockets
        .Package(url: "https://github.com/vapor/socks.git", majorVersion: 1, minor: 0),
        ]
)

let lib = Product(name: "MongoKitten", type: .Library(.Dynamic), modules: "MongoKitten")
