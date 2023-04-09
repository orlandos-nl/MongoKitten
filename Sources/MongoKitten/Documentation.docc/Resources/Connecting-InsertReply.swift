import MongoKitten

// Replace this as appropriate
let connectionString = "mongodb://localhost/my_database"

let db = try await MongoDatabase.connect(to: connectionString)

let users = db["users"]

struct User: Codable {
    let _id: ObjectId
    let name: String
}

let user = User(_id: ObjectId(), name: "Joannis")
let reply = try await users.insertEncoded(user)
print(reply.insertCount)
