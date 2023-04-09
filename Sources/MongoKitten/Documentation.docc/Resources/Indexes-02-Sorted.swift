import MongoKitten

// Replace this as appropriate
let connectionString = "mongodb://localhost/my_database"

let db = try await MongoDatabase.connect(to: connectionString)

struct DummyAccount: Codable, Equatable {
    static let collectionName = "DummyAccounts"

    let _id: ObjectId
    var name: String
    var password: String
    var age: Int

    init(name: String, password: String, age: Int) {
        self._id = ObjectId()
        self.name = name
        self.password = password
        self.age = age
    }
}

let dummyAccounts = db[DummyAccount.collectionName]

try await DummyAccount.buildIndexes {
    SortedIndex(named: "age", field: "age", order: .ascending)
}
