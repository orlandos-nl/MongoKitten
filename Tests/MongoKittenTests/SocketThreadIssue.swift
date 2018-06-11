//
//  SocketThreadIssue.swift
//  MongoKittenTests
//
//  Created by Neal Lester on 6/11/18.
//

import Foundation
import XCTest
import MongoKitten

class SocketThreadIssue: XCTestCase {

    
    func testDemonstrateSocketFailure() throws {
        struct MyStruct: Codable {
            var id = UUID()
        }
        if let connectionString = connectionString() {
            let database = try MongoKitten.Database (connectionString)
            var trialCounter = 0
            let workQueue = DispatchQueue (label: "work", attributes: .concurrent)
            let group = DispatchGroup()
            let collectionName = "testDemonstrateSocketFailure"
            while trialCounter < 500 {
                let intraGroup = DispatchGroup()
                group.enter()
                intraGroup.enter()
                let myStruct = MyStruct()
                workQueue.async {
                    do {
                        let encoder = BSONEncoder()
                        var document = try encoder.encode(myStruct)
                        document["_id"] = myStruct.id.uuidString
                        let collection = database[collectionName]
                        try collection.insert (document)
                        intraGroup.leave()
                    } catch {
                        XCTFail ("\(error)")
                    }
                    switch intraGroup.wait(timeout: DispatchTime.now() + 30.0) {
                    case .success:
                        break
                    default:
                        XCTFail ("Expected .success")
                    }
                    do {
                        let decoder = BSONDecoder()
                        let collection = database[collectionName]
                        let query: Query = "_id" == myStruct.id.uuidString
                        let retrievedDocument = try collection.findOne(query)!
                        let retrievedStruct = try decoder.decode(MyStruct.self, from: retrievedDocument)
                        XCTAssertEqual (myStruct.id.uuidString, retrievedStruct.id.uuidString)
                        group.leave()
                    } catch {
                        XCTFail ("\(error)")
                    }
                }
                trialCounter = trialCounter + 1
            }
            switch group.wait(timeout: DispatchTime.now() + 30.0) {
            case .success:
                break
            default:
                XCTFail ("Expected .success")
            }
            let cleanUpCollection = database[collectionName]
            try cleanUpCollection.remove()
        } else {
            XCTFail ("Please provide result for connectionString()")
        }
        
    }
    
    func connectionString() -> String? {
        return "mongodb://tester:XVpwKjP0hr6ux3yw@danake-shard-00-00-r2jwu.mongodb.net:27017,danake-shard-00-01-r2jwu.mongodb.net:27017,danake-shard-00-02-r2jwu.mongodb.net:27017/test?ssl=true&replicaSet=danake-shard-0&authSource=admin"
    }
    

}
