//
//  DatabaseTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 21/04/16.
//
//

import XCTest
@testable import MongoKitten

class DatabaseTests: XCTestCase {
    static var allTests: [(String, (DatabaseTests) -> () throws -> Void)] {
        return [
                   ("testUsers", testUsers),
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        try! TestManager.clean()
    }
    
    override func tearDown() {
       try! TestManager.disconnect()
    }
    
    func testUsers() throws {
        let roles: Document = [["role": "dbOwner", "db": TestManager.db.name] as Document]
        
        try TestManager.db.createUser("mongokitten-unittest-testuser", password: "hunter2", roles: roles, customData: ["testdata": false])
        
        guard let userInfo = try? TestManager.server.getUserInfo(forUserNamed: "mongokitten-unittest-testuser", inDatabase: TestManager.db), let testData = userInfo[0, "customData", "testdata"] as Bool? else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(testData, false)
        
        try TestManager.db.update(user: "mongokitten-unittest-testuser", password: "hunter2", roles: roles, customData: ["testdata": true])
        
        try TestManager.db.drop(user: "mongokitten-unittest-testuser")
    }
    
//    func testTemporary() throws {
//        let db = try Database(mongoURL: "REDACTED")
//        
//        let kittens = db["kittens"]
//        
//        try kittens.remove(matching: Query([:]))
//        
//        let testQueue = DispatchQueue(label: "org.mongokitten.tests.requestQueue", attributes: .concurrent)
//        
//        var date = Date()
//        date.addTimeInterval(10.0)
//        
//        var ids = [ObjectId]()
//        var total = 0
//        
//        let idLock = NSLock()
//        let semaphore = DispatchSemaphore(value: 1)
//        
//        testQueue.async {
//            while Date() < date {
//                let id = ObjectId()
//                
//                do {
//                    try kittens.insert([
//                        "_id": id,
//                        "works": true
//                        ] as Document)
//                    total += 1
//                } catch {
//                    XCTFail()
//                    continue
//                }
//                
//                idLock.lock()
//                ids.append(id)
//                idLock.unlock()
//            }
//            
//            semaphore.signal()
//        }
//        
//        testQueue.async {
//            while Date() < date {
//                idLock.lock()
//                guard ids.count > 0 else {
//                    idLock.unlock()
//                    continue
//                }
//                let id = ids.removeFirst()
//                idLock.unlock()
//                
//                guard let doc0 = try? kittens.findOne(matching: "_id" == id), let doc = doc0 else {
//                    XCTFail()
//                    continue
//                }
//                
//                guard doc["works"] as Bool? == true else {
//                    XCTFail()
//                    continue
//                }
//            }
//        }
//        
//        semaphore.wait()
//        
//        XCTAssertEqual(try kittens.count(), total)
//    }
    
    func testMakeGridFS() throws {
        let gridFS = try TestManager.db.makeGridFS()
        
        let id = try gridFS.store(data: [0x05, 0x04, 0x01, 0x02, 0x03, 0x00])
        guard let file = try gridFS.findOne(byID: id) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(try file.read(), [0x05, 0x04, 0x01, 0x02, 0x03, 0x00])
        
        XCTAssertEqual(gridFS.chunks.name, "fs.chunks")
        XCTAssertEqual(gridFS.files.name, "fs.files")
    }
}
