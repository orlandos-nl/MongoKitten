//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation
import XCTest
import MongoKitten
import Dispatch


class PerformanceTests: XCTestCase {

    static var allTests: [(String, (PerformanceTests) -> () throws -> Void)] {
        return [
            ("testDispatchInsert", testDispatchInsert),
        ]}
    
    override func setUp() {
        super.setUp()
        
        do {
            try TestManager.clean()
        } catch {
            fatalError("\(error)")
        }
    }
    
    override func tearDown() {
        // Cleaning
        try! TestManager.disconnect()
    }
    
    
    
    func testDispatchInsert() throws {
        let concurrentQueue = DispatchQueue(label: "loader", attributes: .concurrent)
        let dispatchGroup = DispatchGroup()
        
        @discardableResult
        func createCustomers(database: Database, noOfCustomer: Int = 100) -> Bool {
            let collection: MongoKitten.Collection = database["customer"]
            var results = [Any]()
            for index in 1...noOfCustomer {
                let doc: Document = ["_id":index,"name":index]
                concurrentQueue.async(group: dispatchGroup) {
                    do {
                        let result = try collection.insert(doc)
                        results.append(result)
                    } catch {
                        print("Error (processing :\(index)) info: \(error)")
                    }
                }
                
            }
            dispatchGroup.wait()
            XCTAssertEqual(results.count, noOfCustomer)
            return true
        }
        
        for db in TestManager.dbs {
            createCustomers(database: db, noOfCustomer: 100)
        }
    }
}
