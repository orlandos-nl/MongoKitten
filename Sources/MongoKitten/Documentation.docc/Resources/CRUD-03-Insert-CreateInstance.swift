import MongoKitten

// Replace this as appropriate
let connectionString = "mongodb://localhost/my_database"

let db = try await MongoDatabase.connect(to: connectionString)
let kittens = db["kittens"]

import struct Foundation.Date

struct Kitten: Codable {
    let _id: ObjectId
    let name: String
    let age: Date
}

let kitten = Kitten(
    _id: ObjectId(),
    name: "Milo",
    age: Date(timeIntervalSince1970: 1617540152)
)
