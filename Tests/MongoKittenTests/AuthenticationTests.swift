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
                worker: TestManager.loop
            ).blockingAwait(timeout: .seconds(10))
        )
    }
    
    func testAtlas() throws {
        // TODO: Vapor's TLS layer improvements
        let connection = try DatabaseConnection.connect(
            host: MongoHost(hostname: "cluster0-shard-00-01-cgfjh.mongodb.net"),
            credentials: MongoCredentials(username: "mongokitten", password: "f96R1v80KDQIbtUX"),
            ssl: true,
            worker: TestManager.loop
        ).blockingAwait()

        let db = connection["mongokitten-unittest"]

        XCTAssertEqual(try db["zips"].count().blockingAwait(timeout: .seconds(3)), 29353)
        XCTAssertThrowsError(try db["zips"].remove().blockingAwait(timeout: .seconds(3)))
    }

    func testMLabConnection() throws {
        do {
            let connection = try DatabaseConnection.connect(
                host: MongoHost(hostname: "ds047124.mlab.com", port: 47124),
                credentials: MongoCredentials.init(username: "openkitten", password: "test123", database: "plan-t"),
                worker: TestManager.loop
            ).blockingAwait()
            
            let database = connection["plan-t"]

            XCTAssertNotNil(database)

            let collection = database["probe"]
            XCTAssertNotNil(collection)

            let document = try collection.findOne().blockingAwait(timeout: .seconds(30))
            XCTAssertNotNil(document)

            XCTAssertEqual(String(document?["hello"]), "world")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}


