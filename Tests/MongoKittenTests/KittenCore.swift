//
//  KittenCore.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 01/05/2017.
//
//

import XCTest
import Foundation
import BSON
import Cheetah

class Types: XCTestCase {
    static var allTests: [(String, (Types) -> () throws -> Void)] {
        return [
            ("testKittenCoreConversion", testKittenCoreConversion),
        ]
    }
    
    func testKittenCoreConversion() {
        var user = Document()
        let id = ObjectId()
        user["_id"] = id
        user["username"] = "Joannis"
        user["repos"] = ["MongoKitten", "Cheetah", "BSON", "Meow"]
        
        guard let json = user.convert(to: JSONData.self) as? JSONObject else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(String(json["_id"]), id.hexString)
        XCTAssertEqual(String(json["username"]), "Joannis")
        
        guard let repos = Document(user["repos"]), let jsonArray = repos.convert(to: JSONData.self) as? JSONArray else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(jsonArray.count, 4)
        
        XCTAssertEqual(String(jsonArray[0]), "MongoKitten")
        XCTAssertEqual(String(jsonArray[1]), "Cheetah")
        XCTAssertEqual(String(jsonArray[2]), "BSON")
        XCTAssertEqual(String(jsonArray[3]), "Meow")
    }
}
