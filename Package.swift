import PackageDescription

let package = Package(
    name: "MongoKitten",
    dependencies: [
        .Package(url: "https://github.com/PlanTeam/When.git", majorVersion: 0, minor: 1),
        .Package(url: "https://github.com/PlanTeam/BSON.git", majorVersion: 0, minor: 1)
    ]
)