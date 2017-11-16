//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//


import Async
import Dispatch
import Foundation
import BSON
import CryptoKitten

/// Authentication extensions
extension DatabaseConnection {
    /// Generates a random String
    ///
    /// - returns: A random nonce
    private func randomNonce() -> String {
        let allowedCharacters = "!\"#'$%&()*+-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_$"
        
        var randomString = ""
        randomString.reserveCapacity(24)
        
        for _ in 0..<24 {
            let randomNumber: Int
            
            #if os(macOS) || os(iOS)
                randomNumber = Int(arc4random_uniform(UInt32(allowedCharacters.count)))
            #else
                randomNumber = Int(random() % allowedCharacters.count)
            #endif
            
            let letter = allowedCharacters[allowedCharacters.index(allowedCharacters.startIndex, offsetBy: randomNumber)]
            
            randomString.append(letter)
        }
        
        return randomString
    }

    /// Authenticates to this database using MongoDB Challenge Response
    ///
    /// - parameter details: The authentication details
    ///
    /// - throws: When failing authentication, being unable to base64 encode or failing to send/receive messages
    internal func authenticate(mongoCR details: MongoCredentials, usingConnection connection: DatabaseConnection) throws {
        // Get the server's nonce
        let nonceMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: "\(self.name).$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
            "getnonce": Int32(1)
            ], returnFields: nil)

        let response = try server.sendAsync(message: nonceMessage, overConnection: connection).blockingAwait(timeout: .seconds(3))

        // Get the server's challenge
        let document = try firstDocument(in: response)

        guard let nonce = String(document["nonce"]) else {
            log.error("Authentication for MongoDB user \(details.username) with MongoCR failed against \(String(describing: details.database)) because no nonce was provided by MongoDB")
            log.error(document)
            throw AuthenticationError.authenticationFailure
        }

        // Digest our password and prepare it for sending
        var bytes = Bytes()
        bytes.append(contentsOf: "\(details.username):mongo:\(details.password)".utf8)

        let digest = MD5.hash(bytes)
        let key = MD5.hash(Bytes("\(nonce)\(details.username)\(digest.hexString)".utf8)).hexString

        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: "\(self.name).$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
            "authenticate": 1,
            "nonce": nonce,
            "user": details.username,
            "key": key
            ], returnFields: nil)
        let successResponse = try server.sendAsync(message: commandMessage, overConnection: connection).blockingAwait(timeout: .seconds(3))

        let successDocument = try firstDocument(in: successResponse)

        // Check for success
        guard Int(successDocument["ok"]) == 1 else {
            log.error("Authentication for MongoDB user \(details.username) with MongoCR failed against \(String(describing: details.database)) for the following reason")
            log.error(document)
            throw InternalMongoError.incorrectReply(reply: successResponse)
        }
    }
}

extension Server {
    /// Experimental feature for authenticating with MongoDB-X509
    internal func authenticateX509(subject: String, usingConnection connection: DatabaseConnection) throws {
        let message = Message.Query(requestID: nextMessageID(), flags: [], collection: "$external.$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
            "authenticate": 1,
            "mechanism": "MONGODB-X509",
            "user": subject
        ], returnFields: nil)

        let successResponse = try self.sendAsync(message: message, overConnection: connection).blockingAwait(timeout: .seconds(3))

        let successDocument = try firstDocument(in: successResponse)

        // Check for success
        guard Int(successDocument["ok"]) == 1 else {
            throw InternalMongoError.incorrectReply(reply: successResponse)
        }
    }
}


