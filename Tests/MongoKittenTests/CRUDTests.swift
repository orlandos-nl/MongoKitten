import NIO
import MongoKitten
import XCTest

let dbName = "KittenTest"

class CrudTests : XCTestCase {
  struct DummyAccount: Codable {
    static let collectionName = "DummyAccounts"

    let _id = ObjectId()
    var name: String
    var password: String
    var age: Int
  }
  
  let settings = ConnectionSettings(
    authentication: .auto(username: "admin", password: "Autimatisering1"),
    authenticationSource: "admin",
    hosts: [
        .init(hostname: "localhost", port: 27017)
    ],
    targetDatabase: dbName,
    applicationName: "Test MK6"
  )
  var mongo : MongoDatabase!

  override func setUpWithError() throws {
    mongo = try MongoDatabase.synchronousConnect(settings: settings)
  }

  override func tearDownWithError() throws {
    try mongo.drop().wait()
  }

  func testCreateDummyAccount () throws {
    let schema = mongo[DummyAccount.collectionName]
    let startingCount = try schema.count().wait()

    let dummyAccount = DummyAccount(name: "Dum", password: "my", age: 69)
    let _ = try schema.insertEncoded(dummyAccount).wait()
    XCTAssertEqual(try schema.count().wait(), startingCount+1)
  }

  func testBulkCreateDummyAccounts () throws { 
    struct SetupFailed: Error {}
    let schema = mongo[DummyAccount.collectionName]
    let startingCount = try schema.count().wait()

    let dummyAccounts = [
      DummyAccount(name: "Test", password: "ing", age: 77),
      DummyAccount(name: "To", password: "see", age: 8),
      DummyAccount(name: "If", password: "bulk", age: 10),
      DummyAccount(name: "Inserts", password: "will", age: 15),
      DummyAccount(name: "Work", password: "as", age: 19),
      DummyAccount(name: "I", password: "expect", age: 30),
      DummyAccount(name: "Them", password: "to", age: 82),
    ]
    _ = schema.insertManyEncoded(dummyAccounts)
    XCTAssertEqual(try schema.count().wait(), startingCount+7)
  }

  func readDummyAccount (name : String) throws -> DummyAccount? {
    let schema = mongo[DummyAccount.collectionName]
    if let dummy = try schema.findOne("name" == name, as: DummyAccount.self).wait() {
      return dummy
    }
    return nil
  }

  func printDummyAccounts () throws {
    let schema = mongo[DummyAccount.collectionName]
    try schema.find().forEach{ dummy in 
      print("\(dummy["_id"]!): Name - \(dummy["name"]!) | password - \(dummy["password"]!) | age - \(dummy["age"]!)")
    }.wait()
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
    schema.find("age" < 18).forEach{dummy in 
    
      XCTAssertEqual(dummy["name"] as? String, "Underaged")
    }
  }

  func testDeleteDummyAccounts () throws {
    try testBulkCreateDummyAccounts()

    if let dummy = try readDummyAccount(name: "Them") {
      let schema = mongo[DummyAccount.collectionName]
      _ = try schema.deleteOne(where: "_id" == dummy._id).wait()
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

// class RemoteDatabaseCRUDTests : XCTestCase {
//    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
   
// //    let settings = ConnectionSettings(
// //        authentication: .scramSha1(username: "joannis", password: "test"),
// //        authenticationSource: nil,
// //        hosts: [
// //            .init(hostname: "ok0-shard-00-00-xkvc1.mongodb.net", port: 27017)
// //        ],
// //        targetDatabase: nil,
// //        useSSL: true,
// //        verifySSLCertificates: true,
// //        maximumNumberOfConnections: 1,
// //        connectTimeout: 0,
// //        socketTimeout: 0,
// //        applicationName: "Test MK5"
// //    )
   
//    var clean = false
//    let settings = try! ConnectionSettings("mongodb+srv://mongokitten:xrQqOYD28lvAOKXc@ok0-xkvc1.mongodb.net/test?retryWrites=true")
// //    let settings = try! ConnectionSettings("mongodb://localhost")

//    var cluster: Cluster!
   
//    override func setUp() {
//        self.cluster = try! Cluster(lazyConnectingTo: settings, on: group)
       
//        if clean {
//            try! cluster[dbName].drop().wait()
//        }
//    }
   
//    func testTransactions() throws {
//        guard cluster.wireVersion?.supportsReplicaTransactions == true && cluster.isCluster else {
//            return
//        }

//        let db = cluster[dbName]
//        let users = db["users"]
//        _ = try db["users"].insert(["username": "Creating collection user"]).wait()
//        let base = 1
       
//        do {
//            let transactionDB = try db.startTransaction(with: SessionOptions())
//            let transactionUsers = transactionDB["users"]
           
//            XCTAssertEqual(try users.count().wait(), base)
//            _ = try transactionUsers.insert(["username": "henk"]).wait()
//            sleep(2)
//            XCTAssertEqual(try transactionUsers.aggregate().count().wait(), base + 1)
//            XCTAssertEqual(try users.count().wait(), base + 1)
//            try transactionUsers.abort().wait()
//            XCTAssertEqual(try users.count().wait(), base)
//        } catch {
//            XCTFail()
//            return
//        }
       
//        do {
//            let transactionDB = try db.startTransaction(with: SessionOptions())
//            let transactionUsers = transactionDB["users"]
//            XCTAssertEqual(try users.count().wait(), base)
//            _ = try transactionUsers.insert(["username": "henk"]).wait()
//            XCTAssertEqual(try transactionUsers.aggregate().count().wait(), base + 1)
//            XCTAssertEqual(try users.count().wait(), base + 1)
//            try transactionUsers.commit().wait()
//            XCTAssertEqual(try users.count().wait(), base + 1)
//        } catch {
//            XCTFail()
//            return
//        }
//    }
   
//    func testListDatabases() throws {
//        let dbs = try cluster.listDatabases().wait()
       
//        XCTAssertGreaterThan(dbs.count, 0)
//    }
   
//    func testListCollections() throws {
//        print(try cluster["admin"].listCollections().wait().map { $0.fullName })
//    }
   
// //    func testRangeFind() throws {
// //        try connection.flatMap { connection -> EventLoopFuture<Void> in
// //            let collection = connection["test"]["test"]
// //
// //            return self.createTestData(n: 128, in: collection).flatMap {
// //                let findRange = collection.find(inRange: 10..<22).testRange(count: 12)
// //                let findPartialRange = collection.find(inRange: 118...).testRange(startingAt: 118)
// //                let findClosedRange = collection.find(inRange: 10...20).testRange()
// //
// //                return findRange.and(findPartialRange).and(findClosedRange).map { _ in }
// //            }
// //        }.wait()
// //    }
   
// //    func testCluster() throws {
// //        let users = self.cluster[dbName]["users"]
// //        _ = try users.insert(["name": "Joannis"]).wait()
// //        
// //        for i in 0..<100 {
// //            print("Start cycle \(i)")
// //            
// //            let future = users.findOne()
// //                
// //            future.whenSuccess { user in
// //                XCTAssertEqual(user?["name"] as? String, "Joannis")
// //                print("End cycle \(i)")
// //            }
// //            
// //            future.whenFailure { error in
// //                print("\(error)")
// //            }
// //            
// //            sleep(2)
// //        }
// //    }
   
//    func createTestData(n: Int, in collection: MongoKitten.Collection) -> EventLoopFuture<Void> {
//        func nextDocument(index: Int) -> Document {
//            return [
//                "_id": collection.objectIdGenerator.generate(),
//                "n": index
//            ]
//        }
       
//        var future = collection.insert(nextDocument(index: 0))
       
//        for index in 1..<n {
//            future = future.flatMap { _ in
//                return collection.insert(nextDocument(index: index))
//            }
//        }
       
//        return future.map { _ in }
//    }
   
//    func testHenk() throws {
//        let dogs = cluster[dbName]["dogs"]
//        let owners = cluster[dbName]["owners"]
       
//        let ownerId = owners.objectIdGenerator.generate()
//        let dogDoc: Dog = ["_id": dogs.objectIdGenerator.generate(), "owner": ownerId]
//        dogs.insert(dogDoc)
//        owners.insert(["_id": ownerId])
       
//        typealias Dog = Document
//        typealias Owner = Document
       
//        typealias Pair = (Dog, Owner?)
//        struct NoOwnerFoundMeh: Error {}
       
//        try dogs.find().map { dog -> EventLoopFuture<(Dog, Owner)> in
//            guard let ownerId = dog["owner"] as? ObjectId else {
//                throw NoOwnerFoundMeh()
//            }
           
//            return owners.findOne("_id" == ownerId).flatMapThrowing { owner -> (Dog, Owner) in
//                guard let owner = owner else {
//                    struct OwnerUnavailable: Error {}
//                    throw NoOwnerFoundMeh()
//                }

//                return (dog, owner)
//            }
//        }.forEachFuture { dog, owner in
//            XCTAssertEqual(dog, dogDoc)
//            XCTAssertEqual(owner["_id"] as? ObjectId, ownerId)
//        }.wait()
       
//        try dogs.find().forEach { doc in
//            XCTAssertEqual(doc, dogDoc)
//        }.wait()
//    }
   
//    func testGenericFindOne() throws {
//        struct User: Codable {
//            let _id: ObjectId
//            let name: String
           
//            init(named name: String) {
//                self._id = ObjectId()
//                self.name = name
//            }
//        }
       
//        do {
//            let collection = cluster[dbName]["test"]
//            let user = User(named: "Red")
//            _ = try collection.insert(BSONEncoder().encode(user)).wait()
           
//            if let newUser = try collection.findOne("name" == user.name, as: User.self).wait() {
//                XCTAssertEqual(user.name, newUser.name)
//                XCTAssertEqual(user._id, newUser._id)
//            } else {
//                XCTFail()
//            }
//        } catch {
//            XCTFail("\(error)")
//        }
//    }
   
//    func testDefaultOKDecoding() {
//        let doc: Document = [
//            "ok": 1.0
//        ]
       
//        struct Ok: Codable {
//            let ok: Int
//        }
       
//        XCTAssertEqual(try BSONDecoder().decode(Ok.self, from: doc).ok, 1)
//    }
   
//    func testBasicFind() throws {
//        do {
//            let collection = cluster[dbName]["test"]
           
//            try createTestData(n: 241, in: collection).wait()
           
//            var counter = 50
//            try collection.find("n" > 50 && "n" < 223).forEach { doc in
//                counter += 1
//                XCTAssertEqual(doc["n"] as? Int, counter)
//            }.wait()
           
//            XCTAssertEqual(counter, 222)
           
//            counter = 50
//            try collection.find("n" > 50).forEach { doc in
//                counter += 1
//                XCTAssertEqual(doc["n"] as? Int, counter)
//                }.wait()
           
//            XCTAssertEqual(counter, 240)
           
//            counter = 120
//            try collection.find("n" > 50).skip(70).limit(30).forEach { doc in
//                counter += 1
//                XCTAssertEqual(doc["n"] as? Int, counter)
//                }.wait()
           
//            XCTAssertEqual(counter, 150)
           
//            counter = 170
//            try collection.find("n" > 50).skip(70).limit(30).sort(["n": .descending]).forEach { doc in
//                XCTAssertEqual(doc["n"] as? Int, counter)
//                counter -= 1
//                }.wait()
           
//            XCTAssertEqual(counter, 140)
//        } catch {
//            XCTFail("\(error)")
//        }
//    }
   
//    func testChangeStream() throws {
//        guard cluster.wireVersion?.supportsReplicaTransactions == true && cluster.isCluster else {
//            return
//        }
       
//        do {
//            let collection = cluster[dbName]["test"]
           
//            _ = try collection.insert(["_id": ObjectId(), "owner": "Robbert"]).wait()
           
//            let changeStream = try collection.watch().wait()
//            var count = 0
//            let names = ["Joannis" ,"Robbert"]
           
//            changeStream.forEach { notification in
//                XCTAssertEqual(notification.fullDocument?["owner"] as? String, names[count])
//                count += 1
//            }
           
//            XCTAssert(try collection.insert(["_id": ObjectId(), "owner": "Joannis"]).wait().isSuccessful)
//            XCTAssert(try collection.insert(["_id": ObjectId(), "owner": "Robbert"]).wait().isSuccessful)

//            try changeStream.close().wait()
           
//            XCTAssertEqual(count, 2)
//        } catch {
//            XCTFail("\(error)")
//        }
//    }
   
// //    func testUsage() throws {
// //        let total = 152
// //        var n = 0
// //
// //        return try connection.flatMap { connection -> EventLoopFuture<Void> in
// //            let collection = connection["test"]["test"]
// //
// //            return self.createTestData(n: total, in: s).flatMap {
// //                return collection.find()
// //            }.flatMap { cursor -> EventLoopFuture<Void> in
// //                let future = cursor.forEach { doc in
// //                    n += 1
// //                }
// //
// //                future.whenSuccess {
// //                    XCTAssertEqual(total, n, "The amount of inserts did not match the found results")
// //                }
// //
// //                return future
// //            }.flatMap {
// //                return collection.count()
// //            }.flatMap { count -> EventLoopFuture<Int> in
// //                XCTAssertEqual(count, 152, "The count differred from the inserts")
// //
// //                return collection.deleteAll()
// //            }.flatMap { deleted -> EventLoopFuture<Int> in
// //                XCTAssertEqual(deleted, 152, "Not everything was deleted")
// //
// //                return collection.count()
// //            }.map { count -> Void in
// //                XCTAssertEqual(count, 0, "The count differred from the expected of 0 remaining")
// //            }
// //        }.wait()
// //    }
   
// //    func testDistinct() throws {
// //        let values = try connection.flatMap { connection -> EventLoopFuture<[Primitive]> in
// //            let pets = connection["test"]["pets"]
// //
// //            // TODO: Real pet names?
// //            let a = pets.addPet(named: "A", owner: "Joannis")
// //            let b = pets.addPet(named: "B", owner: "Joannis")
// //            let c = pets.addPet(named: "C", owner: "Robbert")
// //            let d = pets.addPet(named: "D", owner: "Robbert")
// //            let e = pets.addPet(named: "E", owner: "Test0")
// //            let f = pets.addPet(named: "F", owner: "Test1")
// //
// //            return a.and(b).and(c).and(d).and(e).and(f).flatMap { _ in
// //                return pets.distinct(onKey: "owner")
// //            }
// //        }.wait()
// //
// //        let owners = Set(values.compactMap { $0 as? String })
// //
// //        XCTAssertEqual(owners, ["Joannis", "Robbert", "Test0", "Test1"])
// //    }
   
// //    func testPipelineUsage() throws {
// //        let pets = try connection.flatMap { connection -> EventLoopFuture<Int> in
// //            let pets = connection["test"]["pets"]
// //
// //            // TODO: Real pet names?
// //            let a = pets.addPet(named: "A", owner: "Joannis")
// //            let b = pets.addPet(named: "B", owner: "Joannis")
// //            let c = pets.addPet(named: "C", owner: "Robbert")
// //            let d = pets.addPet(named: "D", owner: "Robbert")
// //            let e = pets.addPet(named: "E", owner: "Test0")
// //            let f = pets.addPet(named: "F", owner: "Test1")
// //
// //            let inserts = a.and(b).and(c).and(d).and(e).and(f)
// //
// //            return inserts.flatMap { _ in
// //                do {
// //                    let query: Query = "owner" == "Joannis" || "owner" == "Robbert"
// //                    let pipeline = try Pipeline().match(query).count(writingInto: "pets")
// //
// //                    return pets.aggregate(pipeline)
// //                } catch {
// //                    return connection.eventLoop.makeFailedFuture(error)
// //                }
// //            }
// //        }.wait()
// //
// //        XCTAssertEqual(pets, 4)
// //    }
// }

// //extension MongoCollection {
// //    func addPet(named name: String, owner: String) -> EventLoopFuture<Void> {
// //        return self.insert([
// //            "_id": self.objectIdGenerator.generate(),
// //            "name": name,
// //            "owner": owner
// //        ]).map { _ in }
// //    }
// //}
// //
// //extension EventLoopFuture where T == Cursor<Document> {
// //    func testRange(startingAt start: Int64 = 10, count: Int64 = 10) -> EventLoopFuture<Void> {
// //        return self.flatMap { cursor in
// //            var n: Int64 = start
// //
// //            return cursor.forEach { document in
// //                XCTAssertEqual(document["n"] as? Int64, n)
// //                n += 1
// //            }.map {
// //                XCTAssertEqual(n, start + count)
// //            }
// //        }
// //    }
// //}
