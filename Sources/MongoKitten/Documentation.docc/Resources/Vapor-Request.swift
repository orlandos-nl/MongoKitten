import Vapor
import MongoKitten

private struct MongoDBStorageKey: StorageKey {
    typealias Value = MongoDatabase
}

extension Application {
    public var mongoDB: MongoDatabase {
        get {
            storage[MongoDBStorageKey.self]!
        }
        set {
            storage[MongoDBStorageKey.self] = newValue
        }
    }

    public func initializeMongoDB(connectionString: String) throws {
        self.mongoDB = try MongoDatabase.lazyConnect(to: connectionString)
    }
}

extension Request {
    public var mongoDB: MongoDatabase {
        return application.mongoDB.adoptingLogMetadata([
            "request-id": .string(id)
        ])
    }
}
