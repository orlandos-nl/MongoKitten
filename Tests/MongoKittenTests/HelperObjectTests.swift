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

public class HelperObjectTests: XCTestCase {
    public static var allTests: [(String, (HelperObjectTests) -> () throws -> Void)] {
        return [
            ("testIndex", testIndex),
            ("testProjection", testProjection),
            ("testWriteConcern", testWriteConcern),
            ("testReadConcern", testReadConcern),
            ("testCollation", testCollation),
        ]
    }
    
    func testMessageParser() {
        let message: [UInt8] = [
            205, 0, 0, 0, 90, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 169, 0, 0, 0, 8, 105, 115, 109, 97, 115, 116, 101, 114, 0, 1, 16, 109, 97, 120, 66, 115, 111, 110, 79, 98, 106, 101, 99, 116, 83, 105, 122, 101, 0, 0, 0, 0, 1, 16, 109, 97, 120, 77, 101, 115, 115, 97, 103, 101, 83, 105, 122, 101, 66, 121, 116, 101, 115, 0, 0, 108, 220, 2, 16, 109, 97, 120, 87, 114, 105, 116, 101, 66, 97, 116, 99, 104, 83, 105, 122, 101, 0, 232, 3, 0, 0, 9, 108, 111, 99, 97, 108, 84, 105, 109, 101, 0, 206, 116, 18, 198, 92, 1, 0, 0, 16, 109, 97, 120, 87, 105, 114, 101, 86, 101, 114, 115, 105, 111, 110, 0, 5, 0, 0, 0, 16, 109, 105, 110, 87, 105, 114, 101, 86, 101, 114, 115, 105, 111, 110, 0, 0, 0, 0, 0, 8, 114, 101, 97, 100, 79, 110, 108, 121, 0, 0, 1, 111, 107, 0, 0, 0, 0, 0, 0, 0, 240, 63, 0
        ]
        
        var isMasterDoc: Document = [
            "maxWireVersion": Int32(5),
            "maxWriteBatchSize": Int32(1000),
            "ismaster": true,
            "minWireVersion": Int32(0),
            "readOnly": false
        ]
        
        isMasterDoc += [
            "maxBsonObjectSize": Int32(16777216),
            "ok": Double(1),
            "localTime": Date(timeIntervalSince1970: 1497971717.326),
            "maxMessageSizeBytes": Int32(48000000)
        ]
        
        var replyPlaceHolder = ServerReplyPlaceholder()
        
        var block = [UInt8]()
        
        for _ in 0..<message.count * 10 {
            block.append(contentsOf: message)
        }
        
        var size = 210
        var descending = true
        var iterations = 0
        
        while block.count > 0 {
            defer {
                if size == 1 {
                    descending = false
                } else if size == 210 {
                    descending = true
                }
                
                if descending {
                    size -= 1
                } else {
                    size += 1
                }
            }
            
            let end = min(block.count, size)
            var nextBlock = Array(block[0..<end])
            block.removeFirst(end)
            
            while nextBlock.count > 0 {
                let consumed = replyPlaceHolder.process(consuming: &nextBlock, withLengthOf: nextBlock.count)
                
                XCTAssertLessThanOrEqual(consumed, 205)
                
                nextBlock.removeFirst(consumed)
                
                if replyPlaceHolder.isComplete {
                    defer { replyPlaceHolder = ServerReplyPlaceholder() }
                    
                    guard let reply = replyPlaceHolder.construct() else {
                        XCTFail()
                        return
                    }
                    
                    XCTAssertEqual(reply.requestID, 256 + 90)
                    XCTAssertEqual(reply.flags, ReplyFlags(rawValue: 8))
                    XCTAssertEqual(reply.cursorID, 0)
                    XCTAssertEqual(reply.startingFrom, 0)
                    XCTAssertEqual(reply.numbersReturned, 1)
                    XCTAssertEqual(reply.documents.count, 1)
                    XCTAssertEqual(reply.documents.first, isMasterDoc)
                    
                    iterations += 1
                }
            }
        }
        
        XCTAssertEqual(iterations, 2050)
    }
    
    func testIndex() throws {
        XCTAssertEqual(Int32(IndexParameter.TextIndexVersion.one.makePrimitive()), Int32(1))
        XCTAssertEqual(Int32(IndexParameter.TextIndexVersion.two.makePrimitive()), Int32(2))
    }
    
    func testProjection() throws {
        let projection: Projection = [
            "field", "name", "age", "gender"
        ]
        
        XCTAssertEqual(projection.makePrimitive() as? Document, [
                "field": true,
                "name": true,
                "age": true,
                "gender": true
            ])
    }
    
    func testReadConcern() {
        XCTAssertEqual(ReadConcern.local.makePrimitive() as? Document, [
                "level": ReadConcern.local.rawValue
            ])
    }
    
    func testWriteConcern() {
        let concern = WriteConcern.custom(w: "majority", j: true, wTimeout: 0).makePrimitive()
        
        XCTAssertEqual(concern as? Document, [
                "w": "majority",
                "j": true,
                "wtimeout": 0
            ])
    }
    
    func testCollation() {
        
    }
}
