import Hummingbird
import MongoKitten

extension HBApplication {
    public var mongo: MongoDatabase {
        get { extensions.get(\.mongo) }
        set { extensions.set(\.mongo, value: newValue) }
    }
}

extension HBRequest {
    public var mongo: MongoDatabase {
        application.mongo.adoptingLogMetadata([
            "hb_id": .string(id)
        ])
    }
}

extension HBApplicaton {
    public func initializeMongoDB(connectionString: String) throws {
        app.mongo = try MongoDatabase.lazyConnect(to: connectionString)
    }
}
