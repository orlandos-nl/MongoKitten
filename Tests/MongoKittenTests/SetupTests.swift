//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
import XCTest
import MongoKitten
import Foundation

class SetupTests: XCTestCase {
    static var allTests: [(String, (SetupTests) -> () throws -> Void)] {
        return [
//            ("testSetup", testSetup),
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        try! TestManager.clean()
    }
    
    override func tearDown() {
        try! TestManager.disconnect()
    }
    
//    func testSetup() throws {
//        if !TestManager.
//        let server = try Server(mongoURL: "mongodb://mongokitten-unittest-user:mongokitten-unittest-password@127.0.0.1:27017")
//        
//        guard server.contains(where: { db in
//            return db.name == "mongokitten-unittest"
//        }) else {
//            XCTFail()
//            return
//        }
//        
//        let distinct = try server["mongokitten-unittest"]["zips"].distinct(onField: "state")!
//        
//        XCTAssertEqual(distinct.count, 51)
//    }
    
//    func testExample() throws {
//        let database = try Database(mongoURL: "mongodb://127.0.0.1:27017/mongokitten-unittest-mydatabase")
//        let userCollection = database["users"]
//        let otherCollection = database["otherdata"]
//        
//        var userDocument: Document = [
//            "username": "Joannis",
//            "password": "myPassword",
//            "age": 19,
//            "male": true
//        ]
//        
//        let niceBoolean = true
//        
//        let testDocument: Document = [
//            "example": "data",
//            "userDocument": userDocument,
//            "niceBoolean": niceBoolean,
//            "embeddedDocument": [
//                "name": "Henk",
//                "male": false,
//                "age": 12,
//                "pets": ["dog", "dog", "cat", "cat"] as Document
//                ] as Document
//        ]
//        
//        _ = userDocument[raw: "username"]
//        _ = userDocument["username"] as String?
//        _ = userDocument["age"] as String?
//        _ = userDocument[raw: "age"]?.string ?? ""
//        
//        userDocument["bool"] = true
//        userDocument["int32"] = Int32(10)
//        userDocument["int64"] = Int64(200)
//        userDocument["array"] = ["one", 2, "three"] as Document
//        userDocument["binary"] = Binary(data: [0x00, 0x01, 0x02, 0x03, 0x04], withSubtype: .generic)
//        userDocument["date"] = Date()
//        userDocument["null"] = Null()
//        userDocument["string"] = "hello"
//        userDocument["objectID"] = try ObjectId("507f1f77bcf86cd799439011")
//        
//        let trueBool = true
//        userDocument["newBool"] = trueBool
//        
//        _ = try userCollection.insert(userDocument)
//        _ = try otherCollection.insert([testDocument, testDocument, testDocument])
//        
//        let otherResultUsers = try userCollection.find()
//        _ = Array(otherResultUsers)
//        
//        let depletedExample = try userCollection.find()
//        
//        // Contains data
//        _ = Array(depletedExample)
//        
//        // Doesn't contain data
//        _ = Array(depletedExample)
//        
//        let q: Query = "username" == "Joannis" && "age" > 18
//        
//        _ = try userCollection.findOne(matching: q)
//        _ = try userCollection.findOne(matching: q)
//        
//        for user in try userCollection.find(matching: "male" == true) {
//            _ = user[raw: "username"]
//        }
//    }
//    
//    func testFindOnePerformance() throws {
//        
//    }
//    
//    func testFindPerformance() throws {
//        for db in TestManager.dbs {
//            for _ in 0..<2048 {
//                try db["performance"].insert(["val": ObjectId()])
//            }
//            
//            measure {
//                do {
//                    let performanceDocs = Array(try db["performance"].find())
//                    _ = performanceDocs.count
//                } catch {
//                    XCTFail()
//                }
//            }
//        }
//    }
    
    //try database.drop()
}
