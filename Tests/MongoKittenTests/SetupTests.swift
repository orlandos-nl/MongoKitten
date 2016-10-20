//
//  SetupTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 23/03/16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import XCTest
import MongoKitten
import Foundation

class SetupTests: XCTestCase {
    static var allTests: [(String, (SetupTests) -> () throws -> Void)] {
        return [
            ("testSetup", testSetup),
        ]
    }
    
    override func setUp() {
        super.setUp()

        try! TestManager.connect()
        
        try! TestManager.clean()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testSetup() throws {
        let server = try Server(mongoURL: "mongodb://mongokitten-unittest-user:mongokitten-unittest-password@127.0.0.1:27017", automatically: true)
        let distinct = try server["mongokitten-unittest"]["zips"].distinct(onField: "state")!
        
        XCTAssertEqual(distinct.count, 51)
    }
    
    func testExample() throws {
        let server = try Server(mongoURL: "mongodb://127.0.0.1:27017", automatically: true)
        
        let database = server["mongokitten-unittest-mydatabase"]
        let userCollection = database["users"]
        let otherCollection = database["otherdata"]
        
        var userDocument: Document = [
                                         "username": "Joannis",
                                         "password": "myPassword",
                                         "age": 19,
                                         "male": true
                                         ]
        
        let niceBoolean = true
        
        let testDocument: Document = [
                                         "example": "data",
                                         "userDocument": ~userDocument,
                                         "niceBoolean": ~niceBoolean,
                                         "embeddedDocument": [
                                                                 "name": "Henk",
                                                                 "male": false,
                                                                 "age": 12,
                                                                 "pets": ["dog", "dog", "cat", "cat"]
            ]
        ]
        
        _ = userDocument["username"]
        _ = userDocument["username"].stringValue
        _ = userDocument["age"].stringValue
        _ = userDocument["age"].string
        
        userDocument["bool"] = .boolean(true)
        userDocument["int32"] = .int32(10)
        userDocument["int64"] = .int64(200)
        userDocument["array"] = .array(["one", 2, "three"])
        userDocument["binary"] = .binary(subtype: .generic, data: [0x00, 0x01, 0x02, 0x03, 0x04])
        userDocument["date"] = .dateTime(Date())
        userDocument["null"] = .null
        userDocument["string"] = .string("hello")
        userDocument["objectID"] = .objectId(try ObjectId("507f1f77bcf86cd799439011"))
        
        let trueBool = true
        userDocument["newBool"] = ~trueBool
        
        _ = try userCollection.insert(userDocument)
        _ = try otherCollection.insert([testDocument, testDocument, testDocument])
        
        let resultUsers = try userCollection.find()
        
        let otherResultUsers = try userCollection.find()
        _ = Array(otherResultUsers)
        
        let depletedExample = try userCollection.find()
        
        // Contains data
        _ = Array(depletedExample)
        
        // Doesn't contain data
        _ = Array(depletedExample)
        
        let q: Query = "username" == "Joannis" && "age" > 18
        
        _ = try userCollection.findOne(matching: q)
        _ = try userCollection.findOne(matching: q)
        
        for user in try userCollection.find(matching: "male" == true) {
            print(user["username"].string)
        }
    }
    
    //try database.drop()
}
