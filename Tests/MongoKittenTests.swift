//
//  MongoKittenTests.swift
//  MongoKittenTests
//
//  Created by Joannis Orlandos on 31/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import XCTest
import BSON
import When
@testable import MongoKitten

class MongoKittenTests: XCTestCase {
    var database: Database!
    var collection: Collection!
    
    func testNewCode() {
        let server = try! Server(host: "127.0.0.1", port: 27017, autoConnect: true)
        
        self.measureBlock {
            for doc in try! server["test"]["hont"].find() {
                print(doc)
            }
        }
    }
}
