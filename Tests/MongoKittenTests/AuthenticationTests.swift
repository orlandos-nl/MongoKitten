//
//  AuthenticationTests.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 21/01/2017.
//
//

import Foundation
import XCTest
import MongoKitten
import Foundation

class AuthenticationTests: XCTestCase {
    static var allTests: [(String, (AuthenticationTests) -> () throws -> Void)] {
        return [
            ("testMLabConnection", testMLabConnection),
        ]
    }

    override func setUp() {
        super.setUp()


    }

    override func tearDown() {

    }

    func testMLabConnection() throws {
        let clientSettings = ClientSettings(host: MongoHost(hostname:"ds015730.mlab.com", port: 15730),sslSettings: nil,credentials: MongoCredentials(username:"kitten",password:"kitten1234"), maxConnectionsPerServer: 20)

        let server = try Server(clientSettings)
        XCTAssertTrue(server.isConnected)

        let database = server["CloudFoundry_2b5vuc3r_oi9j4527"]

        XCTAssertNotNil(database)

        let collection = database["probe"]
        XCTAssertNotNil(collection)

        let document = try collection.findOne()
        XCTAssertNotNil(document)

        XCTAssertEqual(document?[raw:"hello"]?.string, "world")
    }



}

