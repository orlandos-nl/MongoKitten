import PackageDescription

let package = Package(
    name: "MongoKitten",
    dependencies: [
                      .Package(url: "https://github.com/CryptoKitten/MD5.git", majorVersion: 0, minor: 1),
                      .Package(url: "https://github.com/CryptoKitten/SCRAM.git", majorVersion: 0, minor: 3),
                      .Package(url: "https://github.com/PlanTeam/BSON.git", majorVersion: 1, minor: 2),
                      .Package(url: "https://github.com/ketzusaka/Hummingbird.git", majorVersion: 1, minor: 1),
                      ]
)

let lib = Product(name: "MongoKitten", type: .Library(.Dynamic), modules: "MongoKitten")
