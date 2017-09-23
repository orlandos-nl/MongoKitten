////
//// This source file is part of the MongoKitten open source project
////
//// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
//// Licensed under MIT
////
//// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
//// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
////
//
//import Foundation
//import XCTest
//import MongoKitten
//import Foundation
//
//public class AuthenticationTests: XCTestCase {
//    public static var allTests: [(String, (AuthenticationTests) -> () throws -> Void)] {
//        return [
////            ("testMLabConnection", testMLabConnection),
//        ]
//    }
//
//    public override func setUp() {
//        super.setUp()
//
//
//    }
//
//    public override func tearDown() {
//
//    }
//    
//    func testAtlasFailure() {
//        do {
//            _ = try Server("mongodb://user:WRONG_PASSWORD@cluster0-shard-00-00-cgfjh.mongodb.net:27017,cluster0-shard-00-01-cgfjh.mongodb.net:27017,cluster0-shard-00-02-cgfjh.mongodb.net:27017/admin?ssl=true")
//            
//            XCTFail()
//        } catch {}
//    }
//    
//    func testAtlas() throws {
//        let db = try Database("mongodb://mongokitten:f96R1v80KDQIbtUX@ok0-shard-00-00-xkvc1.mongodb.net:27017,ok0-shard-00-01-xkvc1.mongodb.net:27017,ok0-shard-00-02-xkvc1.mongodb.net:27017/mongokitten-unittest?ssl=true&replicaSet=ok0-shard-0&authSource=admin")
//        
//        XCTAssertEqual(try db["zips"].count(), 29353)
//        XCTAssertThrowsError(try db["zips"].remove())
//    }
//
//    func testMLabConnection() throws {
//        let clientSettings = ClientSettings(host: MongoHost(hostname:"ds047124.mlab.com", port: 47124),sslSettings: nil,credentials: MongoCredentials(username:"openkitten",password:"test123"), maxConnectionsPerServer: 20)
//
//        let server = try Server(clientSettings)
//        XCTAssertTrue(server.isConnected)
//
//        let database = server["plan-t"]
//
//        XCTAssertNotNil(database)
//
//        let collection = database["probe"]
//        XCTAssertNotNil(collection)
//
//        let document = try collection.findOne()
//        XCTAssertNotNil(document)
//
//        XCTAssertEqual(String(document?["hello"]), "world")
//    }
//
//
//
//}
//
