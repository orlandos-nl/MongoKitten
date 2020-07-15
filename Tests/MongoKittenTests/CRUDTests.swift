import NIO
import MongoKitten
import XCTest
import MongoCore

let dbName = "KittenTest"

class CrudTests : XCTestCase {
    struct DummyAccount: Codable {
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
    
    let settings = try! ConnectionSettings("mongodb+srv://AMTester:Autimatisering1@amtestcluster.n5lfc.mongodb.net/\(dbName)?retryWrites=true&w=majority")
    
    //let settings = ConnectionSettings(
    //  authentication: .auto(username: "admin", password: "Autimatisering1"),
    //  authenticationSource: "admin",
    //  hosts: [
    //      .init(hostname: "localhost", port: 27017)
    //  ],
    //  targetDatabase: dbName,
    //  applicationName: "Test MK6"
    //)
    
    var mongo: MongoDatabase!
    var concern: WriteConcern!
    
    override func setUpWithError() throws {
        mongo = try MongoDatabase.synchronousConnect(settings: settings)
        concern = WriteConcern()
        concern.acknowledgement = .majority
    }
    
    override func tearDownWithError() throws {
        try mongo.drop().wait()
    }
    
    func printDummyAccounts () throws {
        let schema = mongo[DummyAccount.collectionName]
        try schema.find().forEach{ dummy in
            print("\(dummy["_id"]!): Name - \(dummy["name"]!) | password - \(dummy["password"]!) | age - \(dummy["age"]!)")
        }.wait()
    }
    
    func executeCommand<E, R>(command: E, replyType: R.Type) -> EventLoopFuture<R> {
        <#function body#>
    }
    
    func testCreateDummyAccount () throws {
        let schema = mongo[DummyAccount.collectionName]
        let startingCount = try schema.count().wait()
        
        let dummyAccount = DummyAccount(name: "Dum", password: "my", age: 69)
        let _ = try schema.insertEncoded(dummyAccount).wait()
        XCTAssertEqual(try schema.count().wait(), startingCount+1)
    }
    
    func testBulkCreateDummyAccounts () throws {
        let dummyAccounts = [
            DummyAccount(name: "Test", password: "ing", age: 77),
            DummyAccount(name: "To", password: "see", age: 8),
            DummyAccount(name: "If", password: "bulk", age: 10),
            DummyAccount(name: "Inserts", password: "will", age: 15),
            DummyAccount(name: "Work", password: "as", age: 19),
            DummyAccount(name: "I", password: "expect", age: 30),
            DummyAccount(name: "Them", password: "to", age: 82),
        ]
        
        let documents = try dummyAccounts.map { dummyAccount in
            try BSONEncoder().encode(dummyAccount)
        }
        
        var command = InsertCommand(documents: documents, inCollection: DummyAccount.collectionName)
        command.writeConcern = concern
        let connection = try mongo.pool.next(for: .init(writable: false)).wait()
        let insertReply = try connection.executeCodable(command, namespace: mongo.commandNamespace, in: nil, sessionId: mongo.sessionId).decodeReply(InsertReply.self).wait()
        
        XCTAssertEqual(insertReply.ok, 1)
        XCTAssertEqual(insertReply.insertCount, dummyAccounts.count)
    }
    
    func readDummyAccount (name : String) throws -> DummyAccount? {
        let schema = mongo[DummyAccount.collectionName]
        return try schema.findOne("name" == name, as: DummyAccount.self).wait()
    }
    
    func testReadDummyAccounts () throws {
        try testBulkCreateDummyAccounts()
        if let dummy = try readDummyAccount(name: "Them") {
            XCTAssertEqual(dummy.password, "to")
            XCTAssertEqual(dummy.age, 82 )
        } else {
            XCTFail("Retrieved a nil value")
        }
    }
    
    func testBulkReadDummyAccounts () throws {
        try testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        var dummyCounter = 0
        
        try schema.find().forEach{ dummy in
            XCTAssertNotNil(dummy)
            dummyCounter+=1
        }.wait()
        XCTAssertEqual(dummyCounter, 7)
    }
    
    func testUpdateDummyAccounts () throws {
        try testBulkCreateDummyAccounts()
        if var dummy = try readDummyAccount(name: "Them") {
            let schema = mongo[DummyAccount.collectionName]
            dummy.name = "UpdateTest"
            _ = try schema.updateEncoded(where: "_id" == dummy._id, to: dummy).wait()
            let updatedDummy = try readDummyAccount(name: "UpdateTest")
            XCTAssertNotNil(updatedDummy)
            XCTAssertEqual(updatedDummy?._id, dummy._id)
        } else {
            XCTFail("Retrieved a nil value")
        }
    }
    
    func testBulkUpdateDummyAccounts() throws {
        try testBulkCreateDummyAccounts()
        
        let schema = mongo[DummyAccount.collectionName]
        _ = try schema.updateMany(where: "age" < 18, to: ["$set" : ["name": "Underaged"]]).wait()
        try schema.find("age" < 18).decode(DummyAccount.self).forEach{dummy in
            XCTAssertEqual(dummy.name, "Underaged")
        }.wait()
    }
    
    func testDeleteDummyAccounts () throws {
        try testBulkCreateDummyAccounts()
        
        if let dummy = try readDummyAccount(name: "Them") {
            let schema = mongo[DummyAccount.collectionName]
            let deleteReply = try schema.deleteOne(where: "_id" == dummy._id).wait()
            XCTAssertEqual(deleteReply.ok, 1)
            XCTAssertEqual(deleteReply.deletes, 1)
            XCTAssertNotEqual(deleteReply.writeErrors?.isEmpty, false)
            sleep(5)
            XCTAssertNil(try readDummyAccount(name: "Them"))
        } else {
            XCTFail("Retrieved a nil value")
        }
    }
    
    func testBulkDeleteDummyAccounts () throws {
        try testBulkCreateDummyAccounts()
        
        let schema = mongo[DummyAccount.collectionName]
        _ = try schema.deleteAll(where: "age" < 18).wait()
        XCTAssertEqual(try schema.count().wait(), 4)
    }
}
