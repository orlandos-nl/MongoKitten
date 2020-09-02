import NIO
import MongoKitten
import XCTest
import MongoCore

let dbName = "KittenTest"

class CrudTests : XCTestCase {
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

    struct DummyAccountAlt: Codable, Equatable {
        static let collectionName = "DummyAccounts"
        
        let _id: ObjectId
        var firstName: String
        var lastName: String
        var age: Int
        
        init(firstName: String, lastName: String, age: Int) {
          self._id = ObjectId()
          self.firstName = firstName
          self.lastName = lastName
          self.age = age
        }
    }
    
    let settings = try! ConnectionSettings("mongodb://localhost:27018/debug")
    
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
    
    // func executeCommand<E, R>(command: E, replyType: R.Type) -> EventLoopFuture<R> {
    //     <#function body#>
    // }
    
    func testCreateDummyAccount () throws {
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        let startingCount: Int = try schema.count().wait()
        
        let dummyAccount = DummyAccount(name: "Dum", password: "my", age: 69)
        _ = try schema.insertEncoded(dummyAccount).wait()
        XCTAssertEqual(try schema.count().wait(), startingCount+1)
    }
    
    // is used repeatedly for all the tests that require dummy data
    func testBackupBulkCreateDummyAccounts () throws -> [DummyAccount] {
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

    // is used repeatedly for some of the tests that require large dummy data
    func testBulkCreateDummyAccounts () throws -> [DummyAccount] {
        var dummyAccounts: [DummyAccount] = []

        for index in 0...4 {
            for age in 1...100 {
                dummyAccounts.append(DummyAccount(name: "Name-\(age + index * 100)", password: "Pass-\(age + index * 100)", age: age))
            }
        }

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
        if let dummy: DummyAccount = try readDummyAccount(name: "Name-182") {
            XCTAssertEqual(dummy.password, "Pass-182")
            XCTAssertEqual(dummy.age, 82 )
        } else {
            XCTFail("Retrieved a nil value")
        }
    }
    
    func testReadLargeBulkAccounts () throws {
        let dummyAccounts: [DummyAccount] = try testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        let age50Duplicates = try schema.find("age" > 50).decode(DummyAccount.self).allResults().wait()
        XCTAssertEqual(age50Duplicates.count, dummyAccounts.filter{$0.age > 50}.count)
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
        let dummyAccounts = try testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        var dummyCounter = 0
        
        try schema.find().forEach{ dummy in
            XCTAssertNotNil(dummy)
            dummyCounter+=1
        }.wait()
        XCTAssertEqual(dummyCounter, dummyAccounts.count)
    }
    
    func testUpdateDummyAccounts () throws {
        let testDummyAccounts = try testBulkCreateDummyAccounts()
        let testDummyAccount = testDummyAccounts[Int.random(in: 0...testDummyAccounts.count)]

        if var account = try readDummyAccount(name: testDummyAccount.name) {
            let schema: MongoCollection = mongo[DummyAccount.collectionName]

            account.name = "UpdateTest"

            _ = try schema.updateEncoded(where: "_id" == account._id, to: account).wait()
            let updatedAccount: DummyAccount? = try readDummyAccount(name: "UpdateTest")

            XCTAssertNotNil(updatedAccount)
            XCTAssertEqual(updatedAccount?._id, account._id)
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
        let testDummyAccounts = try testBulkCreateDummyAccounts()
        let testDummyAccount = testDummyAccounts[Int.random(in: 0...testDummyAccounts.count)]
        
        if let dummy = try readDummyAccount(name: testDummyAccount.name) {
            let schema: MongoCollection = mongo[DummyAccount.collectionName]
            let deleteReply: DeleteReply = try schema.deleteOne(where: "_id" == dummy._id).wait()

            XCTAssertEqual(deleteReply.ok, 1)
            XCTAssertEqual(deleteReply.deletes, 1)
            XCTAssertNotEqual(deleteReply.writeErrors?.isEmpty, false)

            sleep(5)

            XCTAssertNil(try readDummyAccount(name: testDummyAccount.name))
        } else {
            XCTFail()
        }
    }
    
    func testBulkDeleteDummyAccounts () throws {
        let testDummyAccounts = try testBulkCreateDummyAccounts().filter{$0.age >= 18}
        
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        _ = try schema.deleteAll(where: "age" < 18).wait()
        
        XCTAssertEqual(try schema.count().wait(), testDummyAccounts.count)
    }

    func testAggregate () throws {
        try _ = testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        let aggregateBuilderStages: [AggregateBuilderStage] = [
            AggregateBuilderStage.match("age" >= 18),
            AggregateBuilderStage.sort(["age": .ascending]),
            AggregateBuilderStage.limit(3)
        ]
        let results = try schema.aggregate(aggregateBuilderStages).decode(DummyAccount.self).allResults().wait()
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.filter{$0.age >= 18}.count, 3)
        for index in 1 ..< results.count {
            guard results[index-1].age <= results[index].age else {
                XCTFail()
                return
            }
        }
    }

    func testAggregateBuilder () throws {
        try _ = testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        let results = try schema.buildAggregate{
            match("age" >= 18)
            sort(["age": .ascending])
            limit(3)
        }.decode(DummyAccount.self).allResults().wait()

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.filter{$0.age >= 18}.count, 3)
        for index in 1 ..< results.count {
            guard results[index-1].age <= results[index].age else {
                XCTFail()
                return
            }
        }
    }

    func testListCollections () throws {
        _ = try testBulkCreateDummyAccounts()
        XCTAssert(try mongo.listCollections().wait().map{collection -> String in return collection.name}.contains("DummyAccounts"))
    }

    func testFailedConnection () throws {
        let badSettings = try! ConnectionSettings("mongodb+srv://AMTester:Autimatisering1@0.0.0.0/\(dbName)?retryWrites=true&w=majority")
        do {
            _ = try MongoDatabase.synchronousConnect(settings: badSettings)
            XCTFail()
        } catch {
        }
    }
    
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

    // TODO: SequentialForEach
    // func testCursorLoop () throws {
    //     let dummyAccounts = try testBulkCreateDummyAccounts()
    //     let schema: MongoCollection = mongo[DummyAccount.collectionName]
    //     let bla = try schema.find().sequentialForEach{}
    // }
    
    func testGridFSInsert () throws {
        let file = Data(repeating: 0x50, count: 2_000_000)
        let id = ObjectId()
        let gridFS = GridFSBucket(in: mongo)
        try gridFS.upload(file, id: id).wait()
        if let retrievedFile = try gridFS.findFile(byId: id).wait()?.reader.readData().wait() {
            XCTAssertEqual(file, retrievedFile)
        }
    }

    func testFailableAllResults () throws {
        let testDummyAccounts = try testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]
        
        let dummyAccount = DummyAccountAlt(firstName: "OddOne", lastName: "Out", age: 69)
        _ = try schema.insertEncoded(dummyAccount).wait()
        
        let accounts = try schema.find().decode(DummyAccount.self).allResults(failable: true).wait()
        let accountsAlt = try schema.find().decode(DummyAccountAlt.self).allResults(failable: true).wait()

        XCTAssertEqual(accounts.count, testDummyAccounts.count)
        XCTAssertEqual(accountsAlt.count, 1)
    }

    func testFindUpdate () throws {
        let originalAccounts = try testBulkCreateDummyAccounts()
        let schema: MongoCollection = mongo[DummyAccount.collectionName]

        let results = try schema.findAndModify(
            where: "age" == 10, 
            update: ["$set": ["age": 111]], 
            returnValue: FindAndModifyReturnValue.original)
            .execute().wait()
        
        guard let resultValue = results.value else{
            XCTFail()
            return
        }

        let originalAccount = try BSONDecoder().decode(DummyAccount.self, from: resultValue)
        let newAccount = try schema.findOne("age" == 111).decode(DummyAccount.self).wait()
        XCTAssert(originalAccounts.contains(originalAccount))
        XCTAssertEqual(newAccount?.age, 111)
    }

    // func testFindOneAndDelete () throws {
    //     let originalAccounts = try testBulkCreateDummyAccounts()
    //     let schema: MongoCollection = mongo[DummyAccount.collectionName]

    //     let results = try schema.findOneAndDelete(where: ["age": 30]).execute().wait()
        
    //     guard let resultValue = results.value else{
    //         XCTFail()
    //         return
    //     }

    //     let Account = try BSONDecoder().decode(DummyAccount.self, from: resultValue)
    //     XCTAssert(originalAccounts.contains(Account))
    //     schema.findOneAndDelete(where: ["age": 30]).execute().wait()
    // }

    // TODO: Foreach future
    // TODO: Change stream
    // TODO: Find varieties
    // TODO: Indexes
    // TODO: Transactions

}
