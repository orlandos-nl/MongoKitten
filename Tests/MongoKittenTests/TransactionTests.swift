import NIO
import MongoKitten
import XCTest
import MongoCore

class TransactionTests: XCTestCase {
    var mongo: MongoDatabase!
    
    override func setUp() async throws {
        try await super.setUp()
        let mongoSettings: ConnectionSettings
        if let connectionString = ProcessInfo.processInfo.environment["MONGO_TEST_CONNECTIONSTRING"] {
            mongoSettings = try ConnectionSettings(connectionString)
        } else {
            mongoSettings = try ConnectionSettings("mongodb://\(ProcessInfo.processInfo.environment["MONGO_HOSTNAME_A"] ?? "localhost")/mongokitten-test")
        }
        mongo = try await MongoDatabase.connect(to: mongoSettings)
        try await initializeLoggingTracing()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        try await mongo.drop()
    }

    func testTransactionInsert() async throws {
        let startingCount: Int = try await mongo[DummyAccount.collectionName].count()

        try await mongo.transaction { db in
            let schema = db[DummyAccount.collectionName]

            let dummyAccount = DummyAccount(name: "Dum", password: "my", age: 69)
            try await schema.insertEncoded(dummyAccount)
        }

        let count = try await mongo[DummyAccount.collectionName].count()
        XCTAssertEqual(count, startingCount + 1)
    }
    //TODO: this test is failing
//    func test_transaction() async throws {
//        try await mongo.transaction { db in
//            try await db[ModelA.collection].insertEncoded(ModelA(_id: .init(), value: UUID().uuidString))
//            try await db[ModelB.collection].insertEncoded(ModelB(_id: .init(), value: UUID().uuidString))
//        }
//    }
    
    //TODO: this test is failing
//    func test_backToBackTransaction() async throws {
//        for _ in 0..<100 {
//            try await mongo.transaction { db in
//
//                try await db[ModelA.collection].insertEncoded(ModelA(_id: .init(), value: UUID().uuidString))
//                try await db[ModelB.collection].insertEncoded(ModelB(_id: .init(), value: UUID().uuidString))
//            }
//        }
//    }
}


extension MongoDatabase {
    func transaction<T>(_ closure: @escaping (MongoDatabase) async throws -> T) async throws -> T {
        guard !self.isInTransaction else {
            return try await closure(self)
        }
        let transactionDatabase = try await self.startTransaction(autoCommitChanges: false)
        
        do {
            let value = try await closure(transactionDatabase)
            
            try await transactionDatabase.commit()
            return value
        } catch {
            try await transactionDatabase.abort()
            throw error
        }
    }
}
