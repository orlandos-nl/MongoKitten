//
//  ClientSettingsTest.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 04/01/2017.
//
//

import Foundation
import XCTest
@testable import MongoKitten

class ClientSettingsTest: XCTestCase {
    static var allTests: [(String, (ClientSettingsTest) -> () throws -> Void)] {
        return [
                ("testAuthentication", testAuthentication),
                ("testSSLSettings", testSSLSettings)
        ]

    }

    func testAuthentication() throws {

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
