//
//  ServerTests.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 08/12/2016.
//
//

import Foundation
import XCTest
import MongoKitten



class ServerTests: XCTestCase {
    static var allTests: [(String, (ServerTests) -> () throws -> Void)] {
        return [
            ("testSSLConnection", testSSLConnection),
            ("testSSLURLConnection",testSSLURLConnection)
        ]
    }


    func testSSLConnection() throws {

        let server = try Server(hostname: "localhost", port: 27017, authenticatedAs: ("mydbuser","password","mydb"), ssl: true, sslVerify: false)
        XCTAssertTrue(server.isConnected)

    }

    func testSSLURLConnection() throws {

        let server = try Server(mongoURL: "mongodb://mydbuser:password@localhost:27017?ssl=true&sslVerify=false")
        XCTAssertTrue(server.isConnected)

    }
}
