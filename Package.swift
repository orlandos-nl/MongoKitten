import PackageDescription

let package = Package(
    name: "MongoKitten",
    dependencies: [
        // For MongoCR authentication
        .Package(url: "https://github.com/CryptoKitten/MD5.git", majorVersion: 0, minor: 7),
        
        // For SCRAM-SHA-1 authentication
        .Package(url: "https://github.com/CryptoKitten/SCRAM.git", majorVersion: 0, minor: 7),
        .Package(url: "https://github.com/CryptoKitten/SHA1.git", majorVersion: 0, minor: 7),
        
        // For MongoDB Documents
        .Package(url: "https://github.com/PlanTeam/BSON.git", majorVersion: 3),
        
        // For waiting for Documents without blocking the thread
        .Package(url: "https://github.com/ketzusaka/Strand.git", majorVersion: 1, minor: 3),
        ]
)

let lib = Product(name: "MongoKitten", type: .Library(.Dynamic), modules: "MongoKitten")
