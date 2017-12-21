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
import Crypto

/// Authentication extensions
extension DatabaseConnection {
    /// Generates a random String
    ///
    /// - returns: A random nonce
    func randomNonce() -> String {
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
    internal func authenticateCR(_ credentials: MongoCredentials) throws -> Future<Void> {
        // Get the server's nonce
        let nonceMessage = Message.Query(
            requestID: self.nextRequestId,
            flags: [],
            collection: credentials.authDB + ".$cmd",
            numbersToSkip: 0,
            numbersToReturn: 1,
            query: [
                "getnonce": Int32(1)
            ],
            returnFields: nil
        )

        return self.send(message: nonceMessage).flatMap(to: Void.self) { reply in
            guard let nonce = reply.documents.first?["nonce"] as? String else {
                throw AuthenticationError.authenticationFailure
            }
            
            // Digest our password and prepare it for sending
            let data = Data("\(credentials.username):mongo:\(credentials.password)".utf8)
            
            let digest = MD5.hash(data)
            let key = MD5.hash(Data("\(nonce)\(credentials.username)\(digest.hexString)".utf8)).hexString
            
            let commandMessage = Message.Query(
                requestID: self.nextRequestId,
                flags: [],
                collection: credentials.authDB + ".$cmd",
                numbersToSkip: 0,
                numbersToReturn: 1,
                query: [
                    "authenticate": 1,
                    "nonce": nonce,
                    "user": credentials.username,
                    "key": key
                ],
                returnFields: nil
            )
            
            return self.send(message: commandMessage).map(to: Void.self) { reply in
                // Check for success
                guard Int(reply.documents.first?["ok"]) == 1 else {
                    throw MongoError.invalidCredentials(credentials)
                }
            }
        }
    }
}

extension DatabaseConnection {
    /// Experimental feature for authenticating with MongoDB-X509
    internal func authenticateX509(credentials: MongoCredentials) throws -> Future<Void> {
        let message = Message.Query(requestID: self.nextRequestId, flags: [], collection: "$external.$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
            "authenticate": 1,
            "mechanism": "MONGODB-X509",
            "user": credentials.username
        ], returnFields: nil)
        
        return self.send(message: message).map(to: Void.self) { reply in
            // Check for success
            guard Int(reply.documents.first?["ok"]) == 1 else {
                throw MongoError.X509AuthenticationFailed
            }
        }
    }
}
