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
            ("testSSLURLConnection", testSSLURLConnection),
            ("testClientSettingsConnection", testClientSettingsConnection)
        ]
    }


    func testSSLConnection() throws {

        let server = try Server(hostname: "localhost", port: 27017, authenticatedAs: ("mydbuser","password","mydb"), ssl: true, sslVerify: false)
        XCTAssertTrue(server.isConnected)

    }

    func testSSLURLConnection() throws {

        let server = try Server(mongoURL: "mongodb://mydbuser:password@localhost:27017/mydb?ssl=true&sslVerify=false")
        XCTAssertTrue(server.isConnected)
    }

    func testClientSettingsConnection() throws {
        let host = MongoHost(hostName: "localhost", port: 27017)
        let sslSettings = SSLSettings(enabled: true, invalidHostNameAllowed: true, invalidCertificateAllowed: true)
        let credential = MongoCredential(username: "mydbuser", password: "password", database: "mydb", authenticationMechanism: .SCRAM_SHA_1)
        let clientSettings = ClientSettings(hosts: [host], sslSettings: sslSettings, credentials: credential)

        let server = try Server(clientSettings: clientSettings)
        XCTAssertTrue(server.isConnected)
    }
}
