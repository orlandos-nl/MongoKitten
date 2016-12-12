//
//  ClientSetting+URL.swift
//  Galactik
//
//  Created by Laurent Gaches on 12/12/2016.
//
//

import Foundation

extension ClientSettings {
    init(mongoURL url:String) throws {
        var url = url
        guard url.characters.starts(with: "mongodb://".characters) else {
            throw MongoError.noMongoDBSchema
        }

        url.characters.removeFirst("mongodb://".characters.count)

        let parts = url.characters.split(separator: "@")

        guard parts.count <= 2 else {
            throw MongoError.invalidURI(uri: url)
        }

        url = parts.count == 2 ? String(parts[1]) : String(parts[0])

        let queryParts = url.characters.split(separator: "?")

        url = String(queryParts[0])

        var queries = [String: String]()

        if queryParts.count == 2 {
            loop: for keyValue in String(queryParts[1]).characters.split(separator: "&") {
                let keyValue = Array(keyValue).split(separator: "=")

                queries[String(keyValue[0])] = keyValue.count == 2 ? String(keyValue[1]) : ""
            }
        }

        var username: String? = nil
        var password: String? = nil
        var path: String? = nil

        if parts.count == 2 {
            let userString = parts[0]
            let userParts = userString.split(separator: ":")

            guard userParts.count == 2 else {
                throw MongoError.invalidURI(uri: url)
            }

            username = String(userParts[0]).removingPercentEncoding
            password = String(userParts[1]).removingPercentEncoding
        }

        let urlSplitWithPath = url.characters.split(separator: "/")

        url = String(urlSplitWithPath[0])
        path = urlSplitWithPath.count == 2 ? String(urlSplitWithPath[1]) : nil

        var authentication: MongoCredentials? = nil

        if let user = username?.removingPercentEncoding, let pass = password?.removingPercentEncoding {
            let mechanism: AuthenticationMechanism

            switch queries["authMechanism"] ?? "" {
            case "SCRAM_SHA_1":
                mechanism = .SCRAM_SHA_1
            case "MONGODB-CR":
                mechanism = .MONGODB_CR
            case "MONGODB-X509":
                throw MongoError.unsupportedFeature("MONGODB-X509")
            case "GSSAP":
                throw MongoError.unsupportedFeature("GSSAP")
            case "PLAIN":
                throw MongoError.unsupportedFeature("PLAIN")
            default:
                mechanism = .SCRAM_SHA_1
            }

            let authSource = queries["authSource"]

            authentication = MongoCredentials(username: user, password: pass, database: authSource ?? path ?? "admin", authenticationMechanism: mechanism)
        }

        let hosts = url.characters.split(separator: ",").map { host -> MongoHost in
            let hostSplit = host.split(separator: ":")
            var port: UInt16 = 27017

            if hostSplit.count == 2 {
                port = UInt16(String(hostSplit[1])) ?? 27017
            }

            let hostname = String(hostSplit[0])

            return MongoHost(hostname: hostname, port: port)
        }

        let ssl: Bool
        var sslVerify: Bool = false

        if let sslValue = queries["ssl"] {
            ssl = true

            if let _ = queries["sslVerify"] {
                sslVerify = true
            } else {
                sslVerify = false
            }
        } else {
            ssl = false
            
        }
        
        self.init(hosts: hosts, sslSettings: ssl ? SSLSettings(enabled: true, invalidHostNameAllowed: sslVerify, invalidCertificateAllowed: sslVerify) : nil, credentials: authentication, maxConnectionsPerServer: 10)
    }
}
