import PackageDescription

let package = Package(
    name: "MongoKitten",
    dependencies: [
        .Package(url: "https://github.com/PlanTeam/BSON.git", majorVersion: 1, minor: 2),
        .Package(url: "https://github.com/SwiftX/C7.git", majorVersion: 0, minor: 2),
        .Package(url: "https://github.com/ketzusaka/Hummingbird.git", majorVersion: 1, minor: 1),
    ]
)

let lib = Product(name: "MongoKitten", type: .Library(.Dynamic), modules: "MongoKitten")
