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

class ClientSettingsTest: XCTestCase {
    static var allTests: [(String, (ClientSettingsTest) -> () throws -> Void)] {
        return [
                ("testAuthentication", testAuthentication),
                ("testSSLSettings", testSSLSettings),
                ("testMultiHost", testMultiHost),
                ("testInvalidURI", testInvalidURI),
        ]

    }

    func testAuthentication() throws {
        let simpleClientSettings = ClientSettings(host: "openkitten.org:12345", sslSettings: false, credentials: nil)
        
        XCTAssertEqual(simpleClientSettings.sslSettings?.enabled, false)
        XCTAssertNil(simpleClientSettings.credentials)
        XCTAssertEqual(simpleClientSettings.hosts.first?.hostname, "openkitten.org")

        let clientSettings = try ClientSettings(mongoURL: "mongodb://user:password@localhost:1234?authMechanism=MONGODB_CR")
        XCTAssertNotNil(clientSettings.credentials)
        XCTAssertEqual(clientSettings.credentials?.authenticationMechanism, AuthenticationMechanism.MONGODB_CR)
        XCTAssertEqual(clientSettings.credentials?.username, "user")
        XCTAssertEqual(clientSettings.credentials?.password, "password")
        XCTAssertEqual(clientSettings.hosts.count, 1)
        if clientSettings.hosts.count > 0 {
            XCTAssertEqual(clientSettings.hosts[0].hostname, "localhost")
            XCTAssertEqual(clientSettings.hosts[0].port, 1234)
            XCTAssertNil(clientSettings.sslSettings)
        } else {
            XCTFail("Host not found")
        }

        let clientSettingsLowerCase = try ClientSettings(mongoURL: "mongodb://user:passwor@localhost:27017?authMechanism=mongodb_cr")
        XCTAssertNotNil(clientSettingsLowerCase.credentials)
        XCTAssertEqual(clientSettingsLowerCase.credentials?.authenticationMechanism, AuthenticationMechanism.MONGODB_CR)

        let clientSettingFailAuth = try ClientSettings(mongoURL: "mongodb://user:passwor@localhost:27017?authMechanism=mongo")
        XCTAssertNotNil(clientSettingFailAuth.credentials)
        XCTAssertEqual(clientSettingFailAuth.credentials?.authenticationMechanism, AuthenticationMechanism.SCRAM_SHA_1)

        let authSource = try ClientSettings(mongoURL: "mongodb://user:passwor@localhost:27017?authMechanism=SCRAM_SHA_1&authSource=mydbauth")
        XCTAssertNotNil(authSource.credentials)
        XCTAssertEqual(authSource.credentials?.authenticationMechanism, AuthenticationMechanism.SCRAM_SHA_1)
        XCTAssertEqual(authSource.credentials?.database, "mydbauth")

        do {
            let clientAuthFailed = try ClientSettings(mongoURL: "mongodb://user@localhost:27017?authMechanism=mongo")
            XCTAssertNil(clientAuthFailed)
        } catch let error {
            XCTAssertNotNil(error)
        }
    }

    func testInvalidURI() {
        XCTAssertThrowsError(try ClientSettings(mongoURL: "localhost:27017"))
        
        XCTAssertNil(try ClientSettings(mongoURL: "mongodb://localhost:27017/databasename/invalidpath").credentials?.database)
        
        XCTAssertEqual(try ClientSettings(mongoURL: "mongodb://localhost:kaas/baas").hosts[0].port, 27017)
    }

    func testSSLSettings() throws {
        let clientSettings = try ClientSettings(mongoURL:"mongodb://user:passwor@localhost:27017?ssl=false")
        XCTAssertNil(clientSettings.sslSettings)

        let sslClientSettings = try ClientSettings(mongoURL:"mongodb://user:passwor@localhost:27017?ssl=true")
        XCTAssertNotNil(sslClientSettings)
        XCTAssertEqual(sslClientSettings.sslSettings?.enabled, true)
        XCTAssertEqual(sslClientSettings.sslSettings?.invalidCertificateAllowed, false)

        let sslInvalidCertSettings = try ClientSettings(mongoURL:"mongodb://user:passwor@localhost:27017?ssl=true&sslVerify=false")
        XCTAssertNotNil(sslInvalidCertSettings)
        XCTAssertEqual(sslInvalidCertSettings.sslSettings?.enabled, true)
        XCTAssertEqual(sslInvalidCertSettings.sslSettings?.invalidCertificateAllowed, true)


        let sslValidCertSettings = try ClientSettings(mongoURL:"mongodb://user:passwor@localhost:27017?ssl=true&sslVerify=true")
        XCTAssertNotNil(sslValidCertSettings)
        XCTAssertEqual(sslValidCertSettings.sslSettings?.enabled, true)
        XCTAssertEqual(sslValidCertSettings.sslSettings?.invalidCertificateAllowed, false)

        let invalidValueSettings = try ClientSettings(mongoURL:"mongodb://user:passwor@localhost:27017?ssl=test")
        XCTAssertNil(invalidValueSettings.sslSettings)
        
        let SSLsettings: SSLSettings = true
        
        XCTAssertEqual(SSLsettings.enabled, true)
        XCTAssertEqual(SSLsettings.invalidHostNameAllowed, false)
        XCTAssertEqual(SSLsettings.invalidCertificateAllowed, false)
    }
    
    func testHostLiteralExpression() {
        let host1: MongoHost = "example.com"
        let host2: MongoHost = "127.0.0.1:12345"
        let host3: MongoHost = "[2001:0db8:0000:0000:0000:ff00:0042:8329]:12345"
        let host4: MongoHost = "[::1]:12345"
        let host5: MongoHost = "localhost:12345"
        
        XCTAssertEqual(host1.hostname, "example.com")
        XCTAssertEqual(host1.port, 27017)
        
        XCTAssertEqual(host2.hostname, "127.0.0.1")
        XCTAssertEqual(host2.port, 12345)
        
        XCTAssertEqual(host3.hostname, "[2001:0db8:0000:0000:0000:ff00:0042:8329]")
        XCTAssertEqual(host3.port, 12345)
        
        XCTAssertEqual(host4.hostname, "[::1]")
        XCTAssertEqual(host4.port, 12345)
        
        XCTAssertEqual(host5.hostname, "localhost")
        XCTAssertEqual(host5.port, 12345)
    }

    func testMultiHost() throws {
        let clientSettings = try ClientSettings(mongoURL:"mongodb://user:passwor@host1:27018,host2,host3:1234")
        XCTAssertEqual(clientSettings.hosts.count, 3)

        if clientSettings.hosts.count == 3 {
            XCTAssertEqual(clientSettings.hosts[0].hostname, "host1")
            XCTAssertEqual(clientSettings.hosts[0].port, 27018)

            XCTAssertEqual(clientSettings.hosts[1].hostname, "host2")
            XCTAssertEqual(clientSettings.hosts[1].port, 27017)

            XCTAssertEqual(clientSettings.hosts[2].hostname, "host3")
            XCTAssertEqual(clientSettings.hosts[2].port, 1234)
        }
    }
}
