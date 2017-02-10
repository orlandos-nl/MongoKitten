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
@testable import MongoKitten

class GridFSTest: XCTestCase {
    static var allTests: [(String, (GridFSTest) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }

    func testExample() throws {
        for db in TestManager.dbs {
            let fs = try db.makeGridFS()
            
            var file = [UInt8](repeating: 0x01, count: 1_000_000)
            file.append(contentsOf: [UInt8](repeating: 0x02, count: 1_000_000))
            file.append(contentsOf: [UInt8](repeating: 0x03, count: 1_000_000))
            file.append(contentsOf: [UInt8](repeating: 0x04, count: 1_000_000))
            file.append(contentsOf: [UInt8](repeating: 0x05, count: 1_000_000))
            
            let id = try fs.store(data: file, named: "myFile.binary")
            
            guard let dbFile = try fs.findOne(byID: id) else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(dbFile.filename, "myFile.binary")
            
            let data = try dbFile.read(from: 1_500_000, to: 2_500_000)
            var dataEquivalent = [UInt8](repeating: 0x02, count: 500_000)
            dataEquivalent.append(contentsOf: [UInt8](repeating: 0x03, count: 500_000))
            XCTAssertEqual(data.count, 1_000_000)
            XCTAssert(data == dataEquivalent)
            
            var dbFileData = [UInt8]()
            
            for chunk in dbFile {
                dbFileData.append(contentsOf: chunk.data)
            }
            
            XCTAssertEqual(dbFileData, file)
            
            XCTAssertThrowsError(try dbFile.read(from: 4_900_000, to: 5_050_000))
            
            try fs.remove(byId: id)
        }
    }
}
