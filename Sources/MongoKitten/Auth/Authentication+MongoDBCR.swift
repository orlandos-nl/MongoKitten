//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//


import BSON

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
            requestId: nextRequestId,
            flags: [],
            fullCollection: credentials.authDB + ".$cmd",
            skip: 0,
            return: 1,
            query: [
                "getnonce": Int32(1)
            ]
        )

        return self.send(message: nonceMessage).flatMap(to: Void.self) { reply in
            guard let nonce = reply.documents.first?["nonce"] as? String else {
                throw AuthenticationError.authenticationFailure
            }
            
            // Digest our password and prepare it for sending
            let data = MD5()
                .update("\(credentials.username):mongo:\(credentials.password)")
                .finalize()
            
            let digest = MD5()
                .update(data)
                .finalize()
            
            let key = MD5()
                .update("\(nonce)\(credentials.username)\(digest.hexString)")
                .finalize().hexString
            
            let command = MongoDBCRAuth(targetCollection: self["authDB"]["$cmd"], authenticate: 1, nonce: nonce, user: credentials.username, key: key)
            
            return self.execute(command, expecting: Reply.Okay.self).thenThrowing { ok in
                guard ok.ok else {
                    throw MongoError.invalidCredentials(credentials)
                }
            }
        }
    }
}

struct MongoDBCRAuth: Command {
    typealias C = Document
    
    static var writing: Bool { return false }
    static var emitsCursor: Bool { return false }
    
    var targetCollection: MongoCollection<C>
    
    var authenticate: Int32
    var nonce: String
    var user: String
    var key: String
}
