import PackageDescription

var package = Package(
    name: "MongoKitten",
    targets: [
        Target(name: "MongoKitten")
        ],
    dependencies: [
        // For MongoDB Documents
        .Package(url: "https://github.com/OpenKitten/BSON.git", "4.0.0-beta1"),

        // Authentication
        .Package(url: "https://github.com/OpenKitten/CryptoKitten.git", Version(0,0,2)),
        
        // Provides sockets
        .Package(url: "https://github.com/vapor/socks.git", majorVersion: 1),

        // SSL
        .Package(url: "https://github.com/vapor/tls.git", majorVersion: 1),
        ]
)

let lib = Product(name: "MongoKitten", type: .Library(.Dynamic), modules: "MongoKitten")
