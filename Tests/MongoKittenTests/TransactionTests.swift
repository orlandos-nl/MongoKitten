import NIO
import MongoKitten
import XCTest
import MongoCore

class TransactionTests: XCTestCase {
    struct ModelA: Codable {
        static let collection = "model_a"
        let _id: ObjectId
        let value: String
    }
    
    struct ModelB: Codable {
        static let collection = "model_b"
        let _id: ObjectId
        let value: String
    }
    
    var mongo: MongoDatabase!
    
    override func setUp() async throws {
        try await super.setUp()
        let mongoSettings = try ConnectionSettings("mongodb://\(ProcessInfo.processInfo.environment["MONGO_HOSTNAME_A"] ?? "localhost")/mongokitten-test")
        mongo = try await MongoDatabase.connect(to: mongoSettings)
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        try await mongo.drop()
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
