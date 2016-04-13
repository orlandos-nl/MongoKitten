import PackageDescription

let package = Package(
    name: "MongoKitten",
    dependencies: [
                      .Package(url: "https://github.com/cryptokitten/md5.git", majorVersion: 0, minor: 1),
                      .Package(url: "https://github.com/cryptokitten/scram.git", majorVersion: 0, minor: 3),
                      .Package(url: "https://github.com/planteam/bson.git", majorVersion: 1, minor: 2),
                      .Package(url: "https://github.com/qutheory/Hummingbird.git", majorVersion: 2, minor: 0),
                      ]
)

let lib = Product(name: "MongoKitten", type: .Library(.Dynamic), modules: "MongoKitten")
