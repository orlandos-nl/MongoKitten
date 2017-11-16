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
import Foundation

public class AuthenticationTests: XCTestCase {
    public static var allTests: [(String, (AuthenticationTests) -> () throws -> Void)] {
        return [
            ("testMLabConnection", testMLabConnection),
            ("testAtlasFailure", testAtlasFailure),
            ("testAtlas", testAtlas),
        ]
    }

    public override func setUp() {
        super.setUp()
    }
    
    func testAtlasFailure() {
        XCTAssertThrowsError(
            try DatabaseConnection.connect(
                host: MongoHost(hostname: "cluster0-shard-00-01-cgfjh.mongodb.net"),
                credentials: MongoCredentials(username: "user", password: "WRONG_PASSWORD"),
                ssl: true,
                worker: DispatchQueue(label: "test")
            ).blockingAwait(timeout: .seconds(10))
        )
    }
    
    func testAtlas() throws {
        let db = try DatabaseConnection.connect(
            host: MongoHost(hostname: "cluster0-shard-00-01-cgfjh.mongodb.net"),
            credentials: MongoCredentials(username: "mongokitten", password: "f96R1v80KDQIbtUX"),
            ssl: true,
            worker: DispatchQueue(label: "test")
        ).blockingAwait(timeout: .seconds(10))

        XCTAssertEqual(try db["zips"].count(), 29353)
        XCTAssertThrowsError(try db["zips"].remove())
    }

    func testMLabConnection() throws {
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
    }



}


