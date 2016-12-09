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
            ("testSSLURLConnection", testSSLURLConnection),
            ("testClientSettingsConnection", testClientSettingsConnection)
        ]
    }

    func testSSLURLConnection() throws {

        let server = try Server(mongoURL: "mongodb://mydbuser:password@localhost:27017/mydb?ssl=true&sslVerify=false")
        XCTAssertTrue(server.isConnected)
    }

    func testClientSettingsConnection() throws {
        let host = MongoHost(hostname: "localhost", port: 27017)
        let sslSettings = SSLSettings(enabled: true, invalidHostNameAllowed: true, invalidCertificateAllowed: true)
        let credential = MongoCredentials(username: "mydbuser", password: "password", database: "mydb", authenticationMechanism: .SCRAM_SHA_1)
        let clientSettings = ClientSettings(hosts: [host], sslSettings: sslSettings, credentials: credential)

        let server = try Server(clientSettings)
        XCTAssertTrue(server.isConnected)
    }
}
