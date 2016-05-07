import PackageDescription

let package = Package(
    name: "MongoKitten",
    dependencies: [
                      .Package(url: "https://github.com/CryptoKitten/MD5.git", majorVersion: 0, minor: 7),
                      .Package(url: "https://github.com/CryptoKitten/SCRAM.git", majorVersion: 0, minor: 7),
                      .Package(url: "https://github.com/PlanTeam/BSON.git", majorVersion: 2, minor: 3),
                      .Package(url: "https://github.com/CryptoKitten/SHA1.git", majorVersion: 0, minor: 7),
                      .Package(url: "https://github.com/ketzusaka/Strand.git", majorVersion: 1, minor: 2),
                      ]
)

let lib = Product(name: "MongoKitten", type: .Library(.Dynamic), modules: "MongoKitten")
