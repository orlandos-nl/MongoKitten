import PackageDescription

let package = Package(
    name: "MongoKitten",
    dependencies: [
        .Package(url: "https://github.com/PlanTeam/BSON.git", majorVersion: 1),
        .Package(url: "https://github.com/IBM-Swift/BlueSocket.git", Version(0,0,4))
    ]
)