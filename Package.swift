import PackageDescription

var package = Package(
    name: "MongoKitten",
    dependencies: [
        // For MongoCR authentication
        .Package(url: "https://github.com/CryptoKitten/MD5.git", majorVersion: 0, minor: 7),
        
        // For SCRAM-SHA-1 authentication
        .Package(url: "https://github.com/CryptoKitten/SCRAM.git", majorVersion: 0, minor: 7),
        .Package(url: "https://github.com/CryptoKitten/SHA1.git", majorVersion: 0, minor: 7),
        
        // For MongoDB Documents
        .Package(url: "https://github.com/OpenKitten/BSON.git", Version(0,0,0)),
        
        // Provides sockets
        .Package(url: "https://github.com/czechboy0/Socks.git", majorVersion: 0, minor: 7),
        ]
)

#if os(Linux)
    package.dependencies.append(.Package(url: "https://github.com/obbut/Strand.git", Version(0,0,1)))
#else
package.dependencies.append(.Package(url: "https://github.com/loganwright/Strand.git", majorVersion: 2, minor: 0))
#endif

let lib = Product(name: "MongoKitten", type: .Library(.Dynamic), modules: "MongoKitten")
