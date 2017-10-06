////
//// This source file is part of the MongoKitten open source project
////
//// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
//// Licensed under MIT
////
//// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
//// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
////
//
//
//import Async
//import Dispatch
//import Foundation
//import BSON
//import CryptoKitten
//
///// Authentication extensions
//extension Connection {
//    /// Generates a random String
//    ///
//    /// - returns: A random nonce
//    private func randomNonce() -> String {
//        let allowedCharacters = "!\"#'$%&()*+-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_$"
//
//        var randomString = ""
//
//        for _ in 0..<24 {
//            let randomNumber: Int
//
//            #if os(macOS) || os(iOS)
//                randomNumber = Int(arc4random_uniform(UInt32(allowedCharacters.characters.count)))
//            #else
//                randomNumber = Int(random() % allowedCharacters.characters.count)
//            #endif
//
//            let letter = allowedCharacters[allowedCharacters.index(allowedCharacters.startIndex, offsetBy: randomNumber)]
//
//            randomString.append(letter)
//        }
//
//        return randomString
//    }
//
//    /// Parses a SCRAM response
//    ///
//    /// - parameter response: The SCRAM response to parse
//    ///
//    /// - returns: The Dictionary that's build from the response
//    private func parse(response r: String) -> [String: String] {
//        var parsedResponse = [String: String]()
//
//        for part in r.characters.split(separator: ",") where String(part).characters.count >= 3 {
//            let part = String(part)
//
//            if let first = part.characters.first {
//                parsedResponse[String(first)] = String(part[part.index(part.startIndex, offsetBy: 2)..<part.endIndex])
//            }
//        }
//
//        return parsedResponse
//    }
//
//    /// Processes the last step(s) in the SASL process
//    ///
//    /// - parameter payload: The previous payload
//    /// - parameter response: The response we got from the server
//    /// - parameter signature: The server signatue to verify
//    ///
//    /// - throws: On authentication failure or an incorrect Server Signature
//    private func complete(SASL payload: String, using response: Document, verifying signature: Data, to database: Database, promise: Promise<Void>) throws {
//        // If we failed authentication
//        guard Int(response["ok"]) == 1 else {
//            throw AuthenticationError.incorrectCredentials
//        }
//
//        if Bool(response["done"]) == true {
//            promise.complete(())
//            return
//        }
//
//        guard let stringResponse = String(response["payload"]) else {
//            throw AuthenticationError.responseParseError(response: payload)
//        }
//
//        guard let conversationId = response["conversationId"] else {
//            throw AuthenticationError.responseParseError(response: payload)
//        }
//
//        let finalResponseData = try Base64.decode(stringResponse)
//
//        guard let finalResponse = String(bytes: finalResponseData, encoding: String.Encoding.utf8) else {
//            throw MongoError.invalidBase64String
//        }
//
//        let dictionaryResponse = self.parse(response: finalResponse)
//
//        guard let v = dictionaryResponse["v"] else {
//            throw AuthenticationError.responseParseError(response: payload)
//        }
//
//        let serverSignature = try Base64.decode(v)
//
//        guard serverSignature == signature else {
//            throw AuthenticationError.serverSignatureInvalid
//        }
//
//        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: "\(self.name).$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
//            "saslContinue": Int32(1),
//            "conversationId": conversationId,
//            "payload": ""
//            ], returnFields: nil)
//
//        let response = try server.sendAsync(message: commandMessage, overConnection: connection).await(until: .distantFuture)
//
//        try self.complete(SASL: payload, using: response.documents.first ?? [:], verifying: signature, usingConnection: connection)
//    }
//
//    /// Respond to a challenge
//    ///
//    /// - parameter details: The authentication details
//    /// - parameter previousInformation: The nonce, response and `SCRAMClient` instance
//    ///
//    /// - throws: When the authentication fails, when Base64 fails
//    private func challenge(with details: MongoCredentials, using previousInformation: (nonce: String, response: Document, scram: SCRAMClient), to database: Database) throws {
//        // If we failed the authentication
//        guard Int(previousInformation.response["ok"]) == 1 else {
//            throw AuthenticationError.incorrectCredentials
//        }
//
//        // Get our ConversationID
//        guard let conversationId = previousInformation.response["conversationId"] else {
//            throw AuthenticationError.authenticationFailure
//        }
//
//        // Decode the challenge
//        guard let stringResponse = String(previousInformation.response["payload"]) else {
//            throw AuthenticationError.authenticationFailure
//        }
//
//        let stringResponseData = try Base64.decode(stringResponse)
//
//        guard let decodedStringResponse = String(bytes: Array(stringResponseData), encoding: String.Encoding.utf8) else {
//            throw MongoError.invalidBase64String
//        }
//
//        var digestBytes = Bytes()
//        digestBytes.append(contentsOf: "\(details.username):mongo:\(details.password)".utf8)
//
//        var passwordBytes = Bytes()
//        passwordBytes.append(contentsOf: MD5.hash(digestBytes).hexString.utf8)
//
//        let result = try previousInformation.scram.process(decodedStringResponse, with: (username: details.username, password: passwordBytes), usingNonce: previousInformation.nonce)
//
//        // Base64 the payload
//        let payload = Base64.encode(Data(result.proof.utf8))
//
//        log.debug("Responding to the SASL challenge using payload \"\(payload)\"")
//
//        // Send the proof
//        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: "\(self.name).$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
//            "saslContinue": Int32(1),
//            "conversationId": conversationId,
//            "payload": payload
//            ], returnFields: nil)
//
//        let response = try server.sendAsync(message: commandMessage, overConnection: connection).await()
//
//        // If we don't get a correct reply
//
//        // Complete Authentication
//        try self.complete(SASL: payload, using: response.documents.first ?? [:], verifying: Data(result.serverSignature), usingConnection: connection)
//    }
//
//    /// Authenticates to this database using SASL
//    ///
//    /// - parameter details: The authentication details
//    ///
//    /// - throws: When failing authentication, being unable to base64 encode or failing to send/receive messages
//    internal func authenticate(SASL details: MongoCredentials, usingConnection connection: Connection) throws {
//        let nonce = randomNonce()
//
//        let auth = SCRAMClient(server)
//
//        let authPayload = try auth.authenticate(details.username, usingNonce: nonce)
//
//        let payload = Base64.encode(Data(bytes: Array(authPayload.utf8)))
//
//        log.verbose("Starting SASL authentication for \(details.username) against \(details.database ?? "no database")")
//
//        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: "\(self.name).$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
//            "saslStart": Int32(1),
//            "mechanism": "SCRAM-SHA-1",
//            "payload": payload
//            ], returnFields: nil)
//
//        let response = try server.sendAsync(message: commandMessage, overConnection: connection).await()
//
//        let responseDocument = try firstDocument(in: response)
//
//        try self.challenge(with: details, using: (nonce: nonce, response: responseDocument, scram: auth), usingConnection: connection)
//    }
//
//    /// Authenticates to this database using MongoDB Challenge Response
//    ///
//    /// - parameter details: The authentication details
//    ///
//    /// - throws: When failing authentication, being unable to base64 encode or failing to send/receive messages
//    internal func authenticate(mongoCR details: MongoCredentials, usingConnection connection: Connection) throws {
//        // Get the server's nonce
//        let nonceMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: "\(self.name).$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
//            "getnonce": Int32(1)
//            ], returnFields: nil)
//
//        let response = try server.sendAsync(message: nonceMessage, overConnection: connection).await()
//
//        // Get the server's challenge
//        let document = try firstDocument(in: response)
//
//        guard let nonce = String(document["nonce"]) else {
//            log.error("Authentication for MongoDB user \(details.username) with MongoCR failed against \(String(describing: details.database)) because no nonce was provided by MongoDB")
//            log.error(document)
//            throw AuthenticationError.authenticationFailure
//        }
//
//        // Digest our password and prepare it for sending
//        var bytes = Bytes()
//        bytes.append(contentsOf: "\(details.username):mongo:\(details.password)".utf8)
//
//        let digest = MD5.hash(bytes)
//        let key = MD5.hash(Bytes("\(nonce)\(details.username)\(digest.hexString)".utf8)).hexString
//
//        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: "\(self.name).$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
//            "authenticate": 1,
//            "nonce": nonce,
//            "user": details.username,
//            "key": key
//            ], returnFields: nil)
//        let successResponse = try server.sendAsync(message: commandMessage, overConnection: connection).await()
//
//        let successDocument = try firstDocument(in: successResponse)
//
//        // Check for success
//        guard Int(successDocument["ok"]) == 1 else {
//            log.error("Authentication for MongoDB user \(details.username) with MongoCR failed against \(String(describing: details.database)) for the following reason")
//            log.error(document)
//            throw InternalMongoError.incorrectReply(reply: successResponse)
//        }
//    }
//}
//
//extension Server {
//    /// Experimental feature for authenticating with MongoDB-X509
//    internal func authenticateX509(subject: String, usingConnection connection: Connection) throws {
//        log.debug("Starting MONGODB-X509 authentication for subject \"\(subject)\"")
//        
//        let message = Message.Query(requestID: nextMessageID(), flags: [], collection: "$external.$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
//            "authenticate": 1,
//            "mechanism": "MONGODB-X509",
//            "user": subject
//        ], returnFields: nil)
//
//        let successResponse = try self.sendAsync(message: message, overConnection: connection).await()
//
//        let successDocument = try firstDocument(in: successResponse)
//
//        // Check for success
//        guard Int(successDocument["ok"]) == 1 else {
//            log.error("Authentication for MongoDB subject \(subject) with X.509 failed")
//            throw InternalMongoError.incorrectReply(reply: successResponse)
//        }
//    }
//}
//
