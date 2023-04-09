import MongoKitten

// Replace this as appropriate
let connectionString = "mongodb://localhost/my_database"

let db = try await MongoDatabase.connect(to: connectionString)

let users = db["users"]
