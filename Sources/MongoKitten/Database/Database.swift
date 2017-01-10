//
//  Database.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import Foundation
import BSON
import CryptoKitten
import Dispatch
import LogKitten

/// A Mongo Database. Cannot be publically initialized.
/// But you can get a database object by subscripting `Server` with a `String` as the database name
public final class Database {
    /// The `Server` that this Database is a part of
    public let server: Server
    
    /// The database's name
    public let name: String
    
    var logger: FrameworkLogger {
        return server.logger
    }
    
    /// A cache of all collections in this Database.
    ///
    /// Mainly used for keeping track of event listeners
    private var collections = [String: Weak<Collection>]()
    
    #if Xcode
    /// XCode quick look debugging
    func debugQuickLookObject() -> AnyObject {
        var userInfo = ""
        
        if let username = server.clientSettings.credentials?.username {
            userInfo = "\(username):*********@"
        }
        
        var databaseData = ""
        
        if let collections = try? Array(self.listCollections()) {
            databaseData = "Collection count: \(collections.count)\n"
            for collection in collections {
                databaseData.append("- \(collection.name)\n")
            }
        } else {
            databaseData = "Unable to fetch database data"
        }
        
        return NSString(string: "mongodb://\(userInfo)\(server.hostname)/\(self.name)\n\n\(databaseData)")
    }
    #endif
    
    /// Initialise this database object
    ///
    /// - parameter database: The database to use
    /// - parameter server: The `Server` on which this database exists
    public init(named name: String, atServer server: Server) {
        self.server = server
        self.name = name
    }
    
    /// Initializes this Database with a connection String.
    ///
    /// Requires a path with a databasee name
    public init(mongoURL url: String, usingTcpDriver driver: MongoTCP.Type? = nil, maxConnectionsPerServer maxConnections: Int = 10) throws {
        let path = url.characters.split(separator: "/", maxSplits: 2, omittingEmptySubsequences: true)
        
        guard path.count == 3, let dbname = path.last?.split(separator: "?")[0] else {
            throw MongoError.invalidDatabase("")
        }
        
        self.server = try Server(mongoURL: url, maxConnectionsPerServer: maxConnections)
        
        self.name = String(dbname)

        let connection = try server.reserveConnection(writing: false, authenticatedFor: nil)
        
        defer {
            server.returnConnection(connection)
        }
        
        try connection.authenticate(toDatabase: self)
    }
    
    /// A queue to prevent subscripting from creating multiple instances of the same database
    private static let subscriptQueue = DispatchQueue(label: "org.mongokitten.database.subscriptqueue")
    
    /// Creates a GridFS collection in this database
    public func makeGridFS(named name: String = "fs") throws -> GridFS {
        return try GridFS(inDatabase: self, named: name)
    }
    
    /// Get a `Collection` by providing a collection name as a `String`
    ///
    /// - parameter collection: The collection/bucket to return
    ///
    /// - returns: The requested collection in this database
    public subscript (collection: String) -> Collection {
        var c: Collection!
        Database.subscriptQueue.sync {
            collections.clean()
            
            if let col = collections[collection]?.value {
                c = col
                return
            }
            
            c = Collection(named: collection, in: self)
            collections[collection] = Weak(c)
        }
        return c
    }
    
    /// Executes a command `Document` on this database using a query message
    ///
    /// - parameter command: The command `Document` to execute
    /// - parameter timeout: The timeout in seconds for listening for a response
    ///
    /// - returns: A `Message` containing the response
    @discardableResult
    internal func execute(command document: Document, until timeout: TimeInterval = 0, writing: Bool = true) throws -> Message {
        let timeout = timeout > 0 ? timeout : server.defaultTimeout
        
        let connection = try server.reserveConnection(writing: writing, authenticatedFor: self)
        
        defer {
            server.returnConnection(connection)
        }
        
        let cmd = self["$cmd"]
        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: document, returnFields: nil)
        return try server.sendAndAwait(message: commandMessage, overConnection: connection, timeout: timeout)
    }
    
    /// Returns a document that describes the role of the mongod instance.
    ///
    ///If the instance is a member of a replica set, then isMaster returns a subset of the replica set configuration and status including whether or not the instance is the primary of the replica set.
    ///
    /// When sent to a mongod instance that is not a member of a replica set, isMaster returns a subset of this information.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/isMaster/#dbcmd.isMaster
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: `ismaster` response Document
    internal func isMaster() throws -> Document {
        let response = try self.execute(command: ["isMaster": Int32(1)])
        
        return try firstDocument(in: response)
    }
}

/// Authentication extensions
extension Database {
    /// Generates a random String
    ///
    /// - returns: A random nonce
    private func randomNonce() -> String {
        let allowedCharacters = "!\"#'$%&()*+-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_$"
        
        var randomString = ""
        
        for _ in 0..<24 {
            let randomNumber: Int
            
            #if os(Linux)
                randomNumber = Int(random() % allowedCharacters.characters.count)
            #else
                randomNumber = Int(arc4random_uniform(UInt32(allowedCharacters.characters.count)))
            #endif
            
            let letter = allowedCharacters[allowedCharacters.index(allowedCharacters.startIndex, offsetBy: randomNumber)]
            
            randomString.append(letter)
        }
        
        return randomString
    }
    
    /// Parses a SCRAM response
    ///
    /// - parameter response: The SCRAM response to parse
    ///
    /// - returns: The Dictionary that's build from the response
    private func parse(response r: String) -> [String: String] {
        var parsedResponse = [String: String]()
        
        for part in r.characters.split(separator: ",") where String(part).characters.count >= 3 {
            let part = String(part)
            
            if let first = part.characters.first {
                parsedResponse[String(first)] = part[part.index(part.startIndex, offsetBy: 2)..<part.endIndex]
            }
        }
        
        return parsedResponse
    }
    
    /// Processes the last step(s) in the SASL process
    ///
    /// - parameter payload: The previous payload
    /// - parameter response: The response we got from the server
    /// - parameter signature: The server signatue to verify
    ///
    /// - throws: On authentication failure or an incorrect Server Signature
    private func complete(SASL payload: String, using response: Document, verifying signature: [UInt8], usingConnection connection: Connection) throws {
        // If we failed authentication
        guard response["ok"] as Int? == 1 else {
            logger.error("Authentication failed because of the following reason")
            logger.error(response)
            throw MongoAuthenticationError.incorrectCredentials
        }
        
        if response["done"] as Bool? == true {
            logger.verbose("Authentication was successful")
            return
        }
        
        guard let stringResponse = response["payload"] as String? else {
            logger.error("Authentication to MongoDB with SASL failed because no payload has been received")
            logger.debug(response)
            throw MongoAuthenticationError.authenticationFailure
        }
        
        guard let conversationId = response[raw: "conversationId"] else {
            logger.error("Authentication to MongoDB with SASL failed because no conversationId was kept")
            logger.debug(response)
            throw MongoAuthenticationError.authenticationFailure
        }
        
        guard let finalResponseData = Data(base64Encoded: stringResponse), let finalResponse = String(bytes: Array(finalResponseData), encoding: String.Encoding.utf8) else {
            logger.error("Authentication to MongoDB with SASL failed because no valid response was received")
            logger.debug(response)
            throw MongoAuthenticationError.base64Failure
        }
        
        let dictionaryResponse = self.parse(response: finalResponse)
        
        guard let v = dictionaryResponse["v"] else {
            logger.error("Authentication to MongoDB with SASL failed because no valid response was received")
            logger.debug(response)
            throw MongoAuthenticationError.authenticationFailure
        }
        
        guard let serverSignatureData = Data(base64Encoded: v) else {
            logger.error("Authentication to MongoDB with SASL failed because no valid Base64 was received")
            logger.debug(response)
            throw MongoError.invalidBase64String
        }
        
        let serverSignature = Array(serverSignatureData)
        
        guard serverSignature == signature else {
            logger.error("Authentication to MongoDB with SASL failed because the server signature is invalid")
            logger.debug(response)
            throw MongoAuthenticationError.serverSignatureInvalid
        }
        
        let cmd = self["$cmd"]
        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: [
            "saslContinue": Int32(1),
            "conversationId": conversationId,
            "payload": ""
            ], returnFields: nil)
        
        let response = try server.sendAndAwait(message: commandMessage, overConnection: connection, timeout: 0)
        
        guard case .Reply(_, _, _, _, _, _, let documents) = response, let responseDocument = documents.first else {
            logger.error("Authentication to MongoDB with SASL failed because no valid reply was received from MongoDB")
            throw InternalMongoError.incorrectReply(reply: response)
        }
        
        try self.complete(SASL: payload, using: responseDocument, verifying: serverSignature, usingConnection: connection)
    }
    
    /// Respond to a challenge
    ///
    /// - parameter details: The authentication details
    /// - parameter previousInformation: The nonce, response and `SCRAMClient` instance
    ///
    /// - throws: When the authentication fails, when Base64 fails
    private func challenge(with details: MongoCredentials, using previousInformation: (nonce: String, response: Document, scram: SCRAMClient<SHA1>), usingConnection connection: Connection) throws {
        // If we failed the authentication
        guard previousInformation.response["ok"] as Int? == 1 else {
            logger.error("Authentication for MongoDB user \(details.username) with SASL failed against \(details.database) because of the following error")
            logger.error(previousInformation.response)
            throw MongoAuthenticationError.incorrectCredentials
        }
        
        // Get our ConversationID
        guard let conversationId = previousInformation.response[raw: "conversationId"] else {
            logger.error("Authentication for MongoDB user \(details.username) with SASL failed because no conversation has been kept")
            throw MongoAuthenticationError.authenticationFailure
        }
        
        // Decode the challenge
        guard let stringResponse = previousInformation.response["payload"] as String? else {
            logger.error("Authentication for MongoDB user \(details.username) with SASL failed because no SASL payload has been received")
            throw MongoAuthenticationError.authenticationFailure
        }
        
        guard let stringResponseData = Data(base64Encoded: stringResponse), let decodedStringResponse = String(bytes: Array(stringResponseData), encoding: String.Encoding.utf8) else {
            logger.error("Authentication for MongoDB user \(details.username) with SASL failed because no valid Base64 has been received")
            throw MongoAuthenticationError.base64Failure
        }
        
        var digestBytes = [UInt8]()
        digestBytes.append(contentsOf: "\(details.username):mongo:\(details.password)".utf8)
        
        var passwordBytes = [UInt8]()
        passwordBytes.append(contentsOf: MD5.hash(digestBytes).hexString.utf8)
        
        let result = try previousInformation.scram.process(decodedStringResponse, with: (username: details.username, password: passwordBytes), usingNonce: previousInformation.nonce)
        
        
        // Base64 the payload
        let payload = Data(bytes: result.proof.cStringBytes).base64EncodedString()
        
        // Send the proof
        let cmd = self["$cmd"]
        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: [
            "saslContinue": Int32(1),
            "conversationId": conversationId,
            "payload": payload
            ], returnFields: nil)
        
        let response = try server.sendAndAwait(message: commandMessage, overConnection: connection, timeout: 0)
        
        // If we don't get a correct reply
        guard case .Reply(_, _, _, _, _, _, let documents) = response, let responseDocument = documents.first else {
            logger.error("Authentication for MongoDB user \(details.username) with SASL failed against \(details.database) because no valid reply has been received")
            throw InternalMongoError.incorrectReply(reply: response)
        }
        
        // Complete Authentication
        try self.complete(SASL: payload, using: responseDocument, verifying: result.serverSignature, usingConnection: connection)
    }
    
    /// Authenticates to this database using SASL
    ///
    /// - parameter details: The authentication details
    ///
    /// - throws: When failing authentication, being unable to base64 encode or failing to send/receive messages
    internal func authenticate(SASL details: MongoCredentials, usingConnection connection: Connection) throws {
        let nonce = randomNonce()
        
        let auth = SCRAMClient<SHA1>()
        
        let authPayload = try auth.authenticate(details.username, usingNonce: nonce)
        
        let payload = Data(bytes: authPayload.cStringBytes).base64EncodedString()
        
        let cmd = self["$cmd"]
        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: [
            "saslStart": Int32(1),
            "mechanism": "SCRAM-SHA-1",
            "payload": payload
            ], returnFields: nil)
        
        let response = try server.sendAndAwait(message: commandMessage, overConnection: connection, timeout: 0)
        
        let responseDocument = try firstDocument(in: response)
        
        try self.challenge(with: details, using: (nonce: nonce, response: responseDocument, scram: auth), usingConnection: connection)
    }
    
    /// Authenticates to this database using MongoDB Challenge Response
    ///
    /// - parameter details: The authentication details
    ///
    /// - throws: When failing authentication, being unable to base64 encode or failing to send/receive messages
    internal func authenticate(mongoCR details: MongoCredentials, usingConnection connection: Connection) throws {
        // Get the server's nonce
        let response = try self.execute(command: [
            "getnonce": Int32(1)
            ], writing: false)
        
        // Get the server's challenge
        let document = try firstDocument(in: response)
        
        guard let nonce = document["nonce"] as String? else {
            logger.error("Authentication for MongoDB user \(details.username) with MongoCR failed against \(details.database) because no nonce was provided by MongoDB")
            logger.error(document)
            throw MongoAuthenticationError.authenticationFailure
        }
        
        // Digest our password and prepare it for sending
        var bytes = [UInt8]()
        bytes.append(contentsOf: "\(details.username):mongo:\(details.password)".utf8)
        
        let digest = MD5.hash(bytes)
        let key = MD5.hash([UInt8]("\(nonce)\(details.username)\(digest)".utf8)).hexString
        
        let cmd = self["$cmd"]
        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: [
            "authenticate": 1,
            "nonce": nonce,
            "user": details.username,
            "key": key
            ], returnFields: nil)
        let successResponse = try server.sendAndAwait(message: commandMessage, overConnection: connection, timeout: 0)
        
        let successDocument = try firstDocument(in: successResponse)
        
        // Check for success
        guard successDocument["ok"] as Int? == 1 else {
            logger.error("Authentication for MongoDB user \(details.username) with MongoCR failed against \(details.database) for the following reason")
            logger.error(document)
            throw InternalMongoError.incorrectReply(reply: successResponse)
        }
    }
}

extension Database: CustomStringConvertible {
    /// A debugging string
    public var description: String {
        return "MongoKitten.Database<\(server.hostname)/\(self.name)>"
    }
}

extension Database : Sequence {
    /// Iterates over all collections in this database
    public func makeIterator() -> AnyIterator<Collection> {
        let collections = try? self.listCollections().makeIterator()
        
        return AnyIterator {
            return collections?.next()
        }
    }
}
