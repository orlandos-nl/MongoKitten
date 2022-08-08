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
    let settings = try! ConnectionSettings("mongodb://\(ProcessInfo.processInfo.environment["MONGO_HOSTNAME_A"] ?? "localhost")/mongokitten-tests")
    
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
    
    override func setUp() async throws {
        try await super.setUp()
        
        mongo = try await MongoDatabase.connect(to: settings)
        try await mongo.drop()
        concern = WriteConcern()
        concern.acknowledgement = .majority
    }
    
    func testCreateDummyAccount() async throws {
        let schema = mongo[DummyAccount.collectionName]
        let startingCount: Int = try await schema.count()
        
        let dummyAccount = DummyAccount(name: "Dum", password: "my", age: 69)
        try await schema.insertEncoded(dummyAccount)
        let count = try await schema.count()
        XCTAssertEqual(count, startingCount+1)
    }
    
    // is used repeatedly for all the tests that require dummy data
    func BackupBulkCreateDummyAccounts() async throws -> [DummyAccount] {
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
        let connection: MongoConnection = try await mongo.pool.next(for: .writable)
        let insertReply: InsertReply = try await connection.executeCodable(command, decodeAs: InsertReply.self, namespace: mongo.commandNamespace, in: nil, sessionId: mongo.sessionId)
        
        XCTAssertEqual(insertReply.ok, 1)
        XCTAssertEqual(insertReply.insertCount, dummyAccounts.count)
        return dummyAccounts
    }
    
    // is used repeatedly for some of the tests that require large dummy data
    @discardableResult
    func testBulkCreateDummyAccounts() async throws -> [DummyAccount] {
        var dummyAccounts = [DummyAccount]()
        
        for index in 0...2 {
            for age in 1...100 {
                dummyAccounts.append(DummyAccount(name: "Name-\(age + index * 100)", password: "Pass-\(age + index * 100)", age: age))
            }
        }
        
        let documents: [Document] = try dummyAccounts.map { dummyAccount in
            try BSONEncoder().encode(dummyAccount)
        }
        
        var command = InsertCommand(documents: documents, inCollection: DummyAccount.collectionName)
        command.writeConcern = concern
        let connection = try await mongo.pool.next(for: .writable)
        let insertReply = try await connection.executeCodable(command, decodeAs: InsertReply.self, namespace: mongo.commandNamespace, in: nil, sessionId: mongo.sessionId)
        
        XCTAssertEqual(insertReply.ok, 1)
        XCTAssertEqual(insertReply.insertCount, dummyAccounts.count)
        return dummyAccounts
    }
    
    func readDummyAccount (name : String) async throws -> DummyAccount? {
        let schema = mongo[DummyAccount.collectionName]
        return try await schema.findOne("name" == name, as: DummyAccount.self)
    }
    
    func testReadDummyAccounts () async throws {
        let originalAccounts = try await testBulkCreateDummyAccounts()
        let testDummyAccount = originalAccounts[Int.random(in: 0...originalAccounts.count)]
        
        if let dummy: DummyAccount = try await readDummyAccount(name: testDummyAccount.name) {
            XCTAssertEqual(dummy.password, testDummyAccount.password)
            XCTAssertEqual(dummy.age, testDummyAccount.age )
        } else {
            XCTFail("Retrieved a nil value")
        }
    }
    
    func testReadLargeBulkAccounts () async throws {
        let dummyAccounts = try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        let age50Duplicates = try await schema.find("age" > 50).decode(DummyAccount.self).drain()
        XCTAssertEqual(age50Duplicates.count, dummyAccounts.filter{$0.age > 50}.count)
    }
    
    func testReadDistictAge () async throws {
        let dummyAccounts = try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        let ageList: [Int] = try await schema.distinctValues(forKey: "age").compactMap{$0 as? Int}
        
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
    
    func testFindSortedByNameDesc() async throws {
        try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        let accounts: [DummyAccount] = try await schema.find().sort(["name": .descending]).decode(DummyAccount.self).drain()
        
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
    
    func testFindSortedByAgeAsc() async throws {
        try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        let accounts = try await schema.find().sort(["age": .ascending]).decode(DummyAccount.self).drain()
        
        guard accounts.count >= 2 else {
            XCTFail()
            return
        }
        
        for index in 1..<accounts.count {
            guard accounts[index - 1].age <= accounts[index].age else {
                XCTFail()
                return
            }
        }
    }
    
    func testBulkReadDummyAccounts() async throws {
        let dummyAccounts = try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        
        actor Conter {
            var count = 0
            
            func inc() {
                count += 1
            }
        }
        let counter = Conter()
        
        try await schema.find().forEach { dummy in
            XCTAssertNotNil(dummy)
            await counter.inc()
        }.value
        
        let count = await counter.count
        XCTAssertEqual(count, dummyAccounts.count)
    }
    
    func testUpdateDummyAccounts() async throws {
        let testDummyAccounts = try await testBulkCreateDummyAccounts()
        let testDummyAccount = testDummyAccounts[Int.random(in: 0...testDummyAccounts.count)]
        
        if var account = try await readDummyAccount(name: testDummyAccount.name) {
            let schema = mongo[DummyAccount.collectionName]
            
            account.name = "UpdateTest"
            
            _ = try await schema.updateEncoded(where: "_id" == account._id, to: account)
            let updatedAccount = try await readDummyAccount(name: "UpdateTest")
            
            XCTAssertNotNil(updatedAccount)
            XCTAssertEqual(updatedAccount?._id, account._id)
        } else {
            XCTFail("Retrieved a nil value")
        }
    }
    
    func testBulkUpdateDummyAccounts() async throws {
        _ = try await testBulkCreateDummyAccounts()
        
        let schema = mongo[DummyAccount.collectionName]
        _ = try await schema.updateMany(where: "age" < 18, to: ["$set" : ["name": "Underaged"]])
        
        try await schema.find("age" < 18).decode(DummyAccount.self).forEach { dummy in
            XCTAssertEqual(dummy.name, "Underaged")
        }.value
    }
    
    func testDeleteDummyAccounts() async throws {
        let testDummyAccounts = try await testBulkCreateDummyAccounts()
        let testDummyAccount = testDummyAccounts[Int.random(in: 0...testDummyAccounts.count)]
        
        if let dummy = try await readDummyAccount(name: testDummyAccount.name) {
            let schema = mongo[DummyAccount.collectionName]
            let deleteReply = try await schema.deleteOne(where: "_id" == dummy._id)
            
            XCTAssertEqual(deleteReply.ok, 1)
            XCTAssertEqual(deleteReply.deletes, 1)
            XCTAssertNotEqual(deleteReply.writeErrors?.isEmpty, false)
            
            sleep(5)
            
            let dummy = try await readDummyAccount(name: testDummyAccount.name)
            XCTAssertNil(dummy)
        } else {
            XCTFail()
        }
    }
    
    func testBulkDeleteDummyAccounts() async throws {
        let testDummyAccounts = try await testBulkCreateDummyAccounts().filter{$0.age >= 18}
        
        let schema = mongo[DummyAccount.collectionName]
        try await schema.deleteAll(where: "age" < 18)
        let count = try await schema.count()
        XCTAssertEqual(count, testDummyAccounts.count)
    }
    
    func testAggregate() async throws {
        try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        let results = try await schema.buildAggregate {
            Match(where: "age" >= 18)
            Sort(by: "age", direction: .ascending)
            Limit(3)
        }.decode(DummyAccount.self).drain()
        XCTAssertEqual(results.count, 3)
        guard results.count == 3 else {
            XCTFail("Too few results")
            return
        }
        
        for index in 1 ..< results.count {
            guard results[index-1].age <= results[index].age else {
                XCTFail()
                return
            }
        }
    }
    
    func testListCollections() async throws {
        try await testBulkCreateDummyAccounts()
        let collectionNames = try await mongo.listCollections().map(\.name)
        XCTAssertTrue(collectionNames.contains(DummyAccount.collectionName))
    }
    
    func testFailedConnection() async throws {
        let badSettings = try ConnectionSettings("mongodb+srv://AMTester:Autimatisering1@0.0.0.0/\(dbName)?retryWrites=true&w=majority")
        do {
            _ = try await MongoDatabase.connect(to: badSettings)
            XCTFail()
        } catch {}
    }
    
    func testIllegalInsert() async throws {
        try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        guard let account = try await schema.findOne() else {
            XCTFail()
            return
        }
        let reply = try await schema.insert(account)
        XCTAssertEqual(reply.ok, 1)
        XCTAssertEqual(reply.writeErrors?[0].code, 11000)
    }
    
    // TODO: SequentialForEach
    // func testCursorLoop () throws {
    //     let dummyAccounts = try testBulkCreateDummyAccounts()
    //     let schema = mongo[DummyAccount.collectionName]
    //     let bla = try schema.find().sequentialForEach{}
    // }
    
    func testGridFSInsert() async throws {
        let file = Data(repeating: 0x50, count: 2_000_000)
        let id = ObjectId()
        let gridFS = GridFSBucket(in: mongo)
        _ = try await gridFS.upload(file, id: id)
        if let retrievedFile = try await gridFS.findFile(byId: id)?.reader.readData() {
            XCTAssertEqual(file, retrievedFile)
        }
    }
    
    func testFailableAllResults() async throws {
        let testDummyAccounts = try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        
        let dummyAccount = DummyAccountAlt(firstName: "OddOne", lastName: "Out", age: 69)
        try await schema.insertEncoded(dummyAccount, writeConcern: .majority())
        
        let accounts = try await schema.find().decode(DummyAccount.self).drain(failable: true)
        XCTAssertEqual(accounts.count, testDummyAccounts.count)
        
        let accountsAlt = try await schema.find().decode(DummyAccountAlt.self).drain(failable: true)
        XCTAssertEqual(accountsAlt.count, 1)
    }
    
    func testFindUpdate() async throws {
        let originalAccounts = try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        
        let results = try await schema.findAndModify(
            where: "age" == 10,
                 update: ["$set": ["age": 111]],
                 returnValue: FindAndModifyReturnValue.original)
            .execute()
        
        guard let resultValue = results.value else{
            XCTFail()
            return
        }
        
        let originalAccount = try BSONDecoder().decode(DummyAccount.self, from: resultValue)
        let newAccount = try await schema.findOne("age" == 111, as: DummyAccount.self)
        XCTAssert(originalAccounts.contains(originalAccount))
        XCTAssertEqual(newAccount?.age, 111)
    }
    
    func testFindOneAndDelete() async throws {
        let originalAccounts = try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        let testDummyAccount = originalAccounts[Int.random(in: 0...originalAccounts.count)]
        
        let results = try await schema.findOneAndDelete(where: "name" == testDummyAccount.name).execute()
        
        XCTAssertEqual(results.ok, 1)
        
        guard let resultValue = results.value else{
            XCTFail()
            return
        }
        
        let account = try BSONDecoder().decode(DummyAccount.self, from: resultValue)
        XCTAssert(originalAccounts.contains(account))
        
        let exists = try await schema.findOne("_id" == account._id, as: DummyAccount.self) != nil
        if exists {
            XCTFail("Still found the document that was supposed to be deleted")
        }
    }
    
    func testFindOneAndReplace() async throws {
        let originalAccounts = try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        let tempDummyAccount = originalAccounts[Int.random(in: 0...originalAccounts.count)]
        
        guard var testDummyAccount = try await schema.findOne("name" == tempDummyAccount.name, as: DummyAccount.self) else {
            XCTFail()
            return
        }
        
        testDummyAccount.name = "repla"
        testDummyAccount.password = "cement"
        testDummyAccount.age = 111
        let replacement = try BSONEncoder().encode(testDummyAccount)
        
        let results = try await schema.findOneAndReplace(where: "_id" == testDummyAccount._id, replacement: replacement).execute()
        
        XCTAssertEqual(results.ok, 1)
        
        guard let replacedAccount = try await schema.findOne("_id" == testDummyAccount._id, as: DummyAccount.self) else {
            XCTFail()
            return
        }
        XCTAssertEqual(replacedAccount, testDummyAccount)
    }
    
    func testDistinctValues() async throws {
        try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        var results = try await schema.distinctValues(forKey: "name")
        XCTAssertEqual(results.count, 300)
        results = try await schema.distinctValues(forKey: "name", where:  "age" > 50 )
        XCTAssertEqual(results.count, 150)
    }
    
    func testFindOneAndUpdate() async throws {
        let originalAccounts = try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        let tempDummyAccount = originalAccounts[Int.random(in: 0...originalAccounts.count)]
        
        guard let testDummyAccount = try await schema.findOne("name" == tempDummyAccount.name, as: DummyAccount.self) else {
            XCTFail()
            return
        }
        
        let results = try await schema.findOneAndUpdate(where: "_id" == testDummyAccount._id, to: ["$set": ["name": "updated"]]).execute()
        
        XCTAssertEqual(results.ok, 1)
        
        guard let updatedAccount = try await schema.findOne("_id" == testDummyAccount._id, as: DummyAccount.self) else {
            XCTFail()
            return
        }
        XCTAssertEqual(updatedAccount.name, "updated")
    }
    
    func testIndexes () async throws {
        try await testBulkCreateDummyAccounts()
        let schema = mongo[DummyAccount.collectionName]
        
        try await schema.createIndex(named: "nameIndex", keys: ["name": -1])
        let result = try await schema.listIndexes().drain()
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "_id_")
        XCTAssertEqual(result[1].name, "nameIndex")
    }
    
    func testIndexBuilder() async throws {
        let schema = mongo[DummyAccount.collectionName]
        
        try await schema.buildIndexes {
            UniqueIndex(named: "unique-name", field: "name")
        }
        
        let dummyAccount1 = DummyAccount(name: "Dum", password: "test1", age: 1337)
        let dummyAccount2 = DummyAccount(name: "Dum", password: "test2", age: 1338)
               
        let result1 = try await schema.insertEncoded(dummyAccount1)
        XCTAssertEqual(result1.insertCount, 1)
        
        let result2 = try await schema.insertEncoded(dummyAccount2)
        XCTAssertEqual(result2.insertCount, 0)
        
        let count = try await schema.count()
        
        XCTAssertEqual(count, 1)
    }
}
