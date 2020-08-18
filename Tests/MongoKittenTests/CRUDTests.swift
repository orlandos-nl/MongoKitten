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
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        try schema.find().forEach{ dummy in
            print("\(dummy["_id"]!): Name - \(dummy["name"]!) | password - \(dummy["password"]!) | age - \(dummy["age"]!)")
        }.wait()
    }
    
    // func executeCommand<E, R>(command: E, replyType: R.Type) -> EventLoopFuture<R> {
    //     <#function body#>
    // }
    
    func testCreateDummyAccount () throws {
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        let startingCount: Int = try schema.count().wait()
        
        let dummyAccount = DummyAccount(name: "Dum", password: "my", age: 69)
        let _ = try schema.insertEncoded(dummyAccount).wait()
        XCTAssertEqual(try schema.count().wait(), startingCount+1)
    }
    
    // is used repeatedly for all the tests that require dummy data
    func testBulkCreateDummyAccounts () throws -> [DummyAccount] {
        let dummyAccounts = [
            DummyAccount(name: "Test", password: "ing", age: 77),
            DummyAccount(name: "To", password: "see", age: 10),
            DummyAccount(name: "If", password: "bulk", age: 10),
            DummyAccount(name: "Inserts", password: "will", age: 15),
            DummyAccount(name: "Work", password: "as", age: 19),
            DummyAccount(name: "I", password: "expect", age: 30),
            DummyAccount(name: "Them", password: "to", age: 82),
        ]
        
        let documents: [Document] = try dummyAccounts.map { dummyAccount in
            try BSONEncoder().encode(dummyAccount)
        }
        
        var command: InsertCommand = InsertCommand(documents: documents, inCollection: DummyAccount.collectionName)
        command.writeConcern = concern
        let connection: MongoConnection = try mongo.pool.next(for: .init(writable: false)).wait()
        let insertReply: InsertReply = try connection.executeCodable(command, namespace: mongo.commandNamespace, in: nil, sessionId: mongo.sessionId).decodeReply(InsertReply.self).wait()
        
        XCTAssertEqual(insertReply.ok, 1)
        XCTAssertEqual(insertReply.insertCount, dummyAccounts.count)
        return dummyAccounts
    }
    
    func readDummyAccount (name : String) throws -> DummyAccount? {
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        return try schema.findOne("name" == name, as: DummyAccount.self).wait()
    }
    
    func testReadDummyAccounts () throws {
        try _ = testBulkCreateDummyAccounts()
        if let dummy: DummyAccount = try readDummyAccount(name: "Them") {
            XCTAssertEqual(dummy.password, "to")
            XCTAssertEqual(dummy.age, 82 )
        } else {
            XCTFail("Retrieved a nil value")
        }
    }
    
    func testReadDistictAge () throws {
        let dummyAccounts: [DummyAccount] = try testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        let ageList: [Int] = try schema.distinctValues(forKey: "age").wait().compactMap{$0 as? Int}
        
        // confirm the age list has at least 1 item 
        guard ageList.count > 0 else {
            XCTFail()
            return
        }

        for account in dummyAccounts {
            // confirm all ages in the collection were added to the list
            guard (ageList.filter{$0 == account.age}).count > 0 else {
                XCTFail()
                break
            }
        }
        
        for index in 0..<ageList.count {
            // confirm all listed ages appear in the collection
            guard (dummyAccounts.filter{$0.age == ageList[index]}).count > 0 else {
                XCTFail()
                return
            }
            // confirm all listed ages appear only once
            guard (ageList.filter{$0 == ageList[index]}).count == 1 else {
                XCTFail()
                return
            }
        }
    }

    func testFindSortedByNameDesc () throws {
        _ = try testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        let accounts: [DummyAccount] = try schema.find().sort(["name": .descending]).decode(DummyAccount.self).allResults().wait()

        guard accounts.count >= 2 else {
            XCTFail()
            return
        }
        
        for index in 1..<accounts.count {
            guard accounts[index-1].name.compare(accounts[index].name) == ComparisonResult.orderedDescending || 
                accounts[index-1].name.compare(accounts[index].name) == ComparisonResult.orderedSame else {
                XCTFail()
                return
            }
        }
    }

    func testFindSortedByAgeAsc () throws {
        _ = try testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        let accounts: [DummyAccount] = try schema.find().sort(["age": .ascending]).decode(DummyAccount.self).allResults().wait()

        guard accounts.count >= 2 else {
            XCTFail()
            return
        }
        
        for index in 1..<accounts.count {
            guard accounts[index-1].age <= accounts[index].age else {
                XCTFail()
                return
            }
        }
    }

    func testBulkReadDummyAccounts () throws {
        try _ = testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        var dummyCounter = 0
        
        try schema.find().forEach{ dummy in
            XCTAssertNotNil(dummy)
            dummyCounter+=1
        }.wait()
        XCTAssertEqual(dummyCounter, 7)
    }
    
    func testUpdateDummyAccounts () throws {
        try _ = testBulkCreateDummyAccounts()
        if var dummy = try readDummyAccount(name: "Them") {

            let schema: MongoCollection = mongo[DummyAccount.collectionName]
            dummy.name = "UpdateTest"

            _ = try schema.updateEncoded(where: "_id" == dummy._id, to: dummy).wait()
            let updatedDummy: DummyAccount? = try readDummyAccount(name: "UpdateTest")

            XCTAssertNotNil(updatedDummy)
            XCTAssertEqual(updatedDummy?._id, dummy._id)
        } else {
            XCTFail("Retrieved a nil value")
        }
    }
    
    func testBulkUpdateDummyAccounts() throws {
        try _ = testBulkCreateDummyAccounts()
        
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        _ = try schema.updateMany(where: "age" < 18, to: ["$set" : ["name": "Underaged"]]).wait()

        try schema.find("age" < 18).decode(DummyAccount.self).forEach{dummy in
            XCTAssertEqual(dummy.name, "Underaged")
        }.wait()
    }
    
    func testDeleteDummyAccounts () throws {
        try _ = testBulkCreateDummyAccounts()
        
        if let dummy = try readDummyAccount(name: "Them") {
            let schema: MongoCollection = mongo[DummyAccount.collectionName]
            let deleteReply: DeleteReply = try schema.deleteOne(where: "_id" == dummy._id).wait()

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
        try _ = testBulkCreateDummyAccounts()
        
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        _ = try schema.deleteAll(where: "age" < 18).wait()
        
        XCTAssertEqual(try schema.count().wait(), 4)
    }

    func testAggregate () throws {
        try _ = testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        let AggregateBuilderStages: [AggregateBuilderStage] = [
            AggregateBuilderStage.match("age" >= 18),
            AggregateBuilderStage.sort(["age": .ascending]),
            AggregateBuilderStage.limit(3)
        ]
        let results = try schema.aggregate(AggregateBuilderStages).decode(DummyAccount.self).allResults().wait()
        XCTAssertEqual(results[0].age, 19)
        XCTAssertEqual(results[1].age, 30)
        XCTAssertEqual(results[2].age, 77)
    }

    func testListCollections () throws {
        _ = try testBulkCreateDummyAccounts()
        XCTAssert(try mongo.listCollections().wait().map{collection -> String in return collection.name}.contains("DummyAccounts"))
    }

    func testFailedConnection () throws {
        let badSettings = try! ConnectionSettings("mongodb+srv://AMTester:Autimatisering1@0.0.0.0/\(dbName)?retryWrites=true&w=majority")
        do {
            _ = try MongoDatabase.synchronousConnect(settings: badSettings)
        } catch {
            return
        }
        XCTFail()
    }
    
    // TODO: adds minimal contribution, remove?
    func testIllegalInsert () throws {
        _ = try testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        guard let account = try schema.findOne().wait() else {
            XCTFail()
            return
        }
        let reply = try schema.insert(account).wait()
        XCTAssertEqual(reply.ok, 1)
        XCTAssertEqual(reply.writeErrors?[0].code, 11000)
    }

    // TODO: Does not raise coverage score, remove? 
    //
    // func testCursorLoop () throws {
    //     _ = try testBulkCreateDummyAccounts()
    //     let schema: MongoCollection = mongo[DummyAccount.collectionName]
    //     var cursorDummyAccounts: [DummyAccount] = []
    //     try schema.find().forEach { (account: Document) -> Void in 
    //         cursorDummyAccounts.append(try BSONDecoder().decode(DummyAccount.self, from: account))
    //     }.wait()
    //     XCTAssertGreaterThan(cursorDummyAccounts.count, 0)
    // }


    //TODO: ask yoanis about testfile and constrainsts surrounding it
    
    func testGridFSInsert () throws {
        let file = Data(repeating: 0x50, count: 2_000_000)
        let id = ObjectId()
        let gridFS = GridFSBucket(in: mongo)
        try gridFS.upload(file, id: id).wait()
        if let retrievedFile = try gridFS.findFile(byId: id).wait()?.reader.readData().wait() {
            XCTAssertEqual(file, retrievedFile)
        }
    }


}
