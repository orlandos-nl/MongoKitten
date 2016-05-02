//
//  Database.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 27/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import MD5
import SCRAM
import SHA1
import Foundation
import PBKDF2
import BSON
import HMAC

/// A Mongo Database. Cannot be publically initialized. But you can get a database object by subscripting a Server with a String
public final class Database {
    /// The server that this Database is a part of
    public let server: Server
    
    /// The database's name
    public let name: String
    
    /// Are we authenticated?
    public internal(set) var isAuthenticated = true
    
    /// Initialise this database object
    /// - parameter database: The database to use
    /// - parameter server: The server on which this database exists
    public init(database: String, at server: Server) {
        self.server = server
        self.name = replaceOccurrences(in: database, where: ".", with: "")
    }
    
    /// This subscript is used to get a collection by providing a name as a String
    /// - parameter collection: The collection/bucket to return
    /// - returns: The requested collection in this database
    public subscript (collection: String) -> Collection {
        return Collection(named: collection, in: self)
    }
    
    /// Executes a command on this database using a query message
    /// - parameter command: The command Document to execute
    /// - returns: A message containing the response
    internal func execute(command: Document, until timeout: NSTimeInterval = 60) throws -> Message {
        let cmd = self["$cmd"]
        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: command, returnFields: nil)
        let id = try server.send(message: commandMessage)
        return try server.await(response: id, until: timeout)
    }
    
    /// All information about the collecitons in this Database
    /// - parameter matching: The filter to apply when searching for this information
    /// - returns: A cursor to the resulting documents with collection info
    @warn_unused_result
    public func getCollectionInfos(matching filter: Document? = nil) throws -> Cursor<Document> {
        var request: Document = ["listCollections": 1]
        if let filter = filter {
            request["filter"].value = filter
        }
        
        let reply = try execute(command: request)
        
        let result = try firstDocument(in: reply)
        
        let code = result["ok"].int32
        guard let cursor = result["cursor"].documentValue where code == 1 else {
            throw MongoError.CommandFailure
        }
        
        return try Cursor(cursorDocument: cursor, server: server, chunkSize: 10, transform: { $0 })
    }
    
    /// Gets the collections in this database
    /// - parameter matching: The filter to apply when looking for Collections
    @warn_unused_result
    public func getCollections(matching filter: Document? = nil) throws -> Cursor<Collection> {
        let infoCursor = try self.getCollectionInfos(matching: filter)
        return Cursor(base: infoCursor) { collectionInfo in
            return self[collectionInfo["name"].string]
        }
    }
    
    /// Looks for `ismaster` information
    /// - returns: `ismaster` response Document
    @warn_unused_result
    internal func isMaster() throws -> Document {
        let response = try self.execute(command: ["ismaster": .int32(1)])
        
        return try firstDocument(in: response)
    }
}

/// Authentication and encryption
extension Database {
    /// Generates a random String
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
            
            let letter = allowedCharacters[allowedCharacters.startIndex.advanced(by: randomNumber)]
            
            randomString.append(letter)
        }
        
        return randomString
    }
    
    /// Parses a SCRAM response
    private func parse(response: String) -> [String: String] {
        var parsedResponse = [String: String]()
        
        for part in response.characters.split(separator: ",") where String(part).characters.count >= 3 {
            let part = String(part)
            
            if let first = part.characters.first {
                parsedResponse[String(first)] = part[part.startIndex.advanced(by: 2)..<part.endIndex]
            }
        }
        
        return parsedResponse
    }
    
    /// Last step(s) in the SASL process
    /// TODO: Set a timeout for connecting
    private func complete(SASL payload: String, using response: Document, verifying signature: [UInt8]) throws {
        // If we failed authentication
        guard response["ok"].int32 == 1 else {
            throw MongoAuthenticationError.IncorrectCredentials
        }
        
        guard let stringResponse = response["payload"].stringValue else {
            throw MongoAuthenticationError.AuthenticationFailure
        }
        
        let conversationId = response["conversationId"]
        guard conversationId != .nothing  else {
            throw MongoAuthenticationError.AuthenticationFailure
        }
        
        guard let finalResponse = String(bytes: [Byte](base64: stringResponse), encoding: NSUTF8StringEncoding) else {
            throw MongoAuthenticationError.Base64Failure
        }
        
        let dictionaryResponse = self.parse(response: finalResponse)
        
        guard let v = dictionaryResponse["v"] else {
            throw MongoAuthenticationError.AuthenticationFailure
        }
        
        let serverSignature = [Byte](base64: v)
        
        guard serverSignature == signature else {
            throw MongoAuthenticationError.ServerSignatureInvalid
        }
        
        let response = try self.execute(command: [
                                                   "saslContinue": .int32(1),
                                                   "conversationId": conversationId,
                                                   "payload": ""
            ])
        
        guard case .Reply(_, _, _, _, _, _, let documents) = response, let responseDocument = documents.first else {
            throw InternalMongoError.IncorrectReply(reply: response)
        }
        
        try self.complete(SASL: payload, using: responseDocument, verifying: serverSignature)
    }
    
    /// Respond to a challenge
    /// TODO: Set a timeout for connecting
    private func challenge(with details: (username: String, password: String, against: String), using previousInformation: (nonce: String, response: Document, scram: SCRAMClient<SHA1>)) throws {
        // If we failed the authentication
        guard previousInformation.response["ok"].int32 == 1 else {
            throw MongoAuthenticationError.IncorrectCredentials
        }
        
        // Get our ConversationID
        let conversationId = previousInformation.response["conversationId"]
        guard conversationId != .nothing  else {
            throw MongoAuthenticationError.AuthenticationFailure
        }
        
        // Decode the challenge
        guard let stringResponse = previousInformation.response["payload"].stringValue else {
            throw MongoAuthenticationError.AuthenticationFailure
        }
        
        guard let decodedStringResponse = String(bytes: [Byte](base64: stringResponse), encoding: NSUTF8StringEncoding) else {
            throw MongoAuthenticationError.Base64Failure
        }
        
        var digestBytes = [Byte]()
        digestBytes.append(contentsOf: "\(details.username):mongo:\(details.password)".utf8)
        
        var passwordBytes = [Byte]()
        passwordBytes.append(contentsOf: MD5.calculate(digestBytes).hexString.utf8)
        
        let result = try previousInformation.scram.process(decodedStringResponse, with: (username: details.username, password: passwordBytes), usingNonce: previousInformation.nonce)
        
        
        // Base64 the payload
        guard let payload = result.proof.cStringBsonData.base64 else {
            throw MongoAuthenticationError.Base64Failure
        }
        
        // Send the proof
        let response = try self.execute(command: [
                                                   "saslContinue": .int32(1),
                                                   "conversationId": conversationId,
                                                   "payload": .string(payload)
            ])
        
        // If we don't get a correct reply
        guard case .Reply(_, _, _, _, _, _, let documents) = response, let responseDocument = documents.first else {
            throw InternalMongoError.IncorrectReply(reply: response)
        }
        
        // Complete Authentication
        try self.complete(SASL: payload, using: responseDocument, verifying: result.serverSignature)
    }
    
    /// Authenticates to this database using SASL
    /// TODO: Support authentication DBs
    /// TODO: Set a timeout for connecting
    internal func authenticate(SASL details: (username: String, password: String, against: String)) throws {
        let nonce = randomNonce()
        
        let auth = SCRAMClient<SHA1>()
        
        let authPayload = try auth.authenticate(details.username, usingNonce: nonce)
        
        guard let payload = authPayload.cStringBsonData.base64 else {
            throw MongoAuthenticationError.Base64Failure
        }
        
        let response = try self.execute(command: [
                                                   "saslStart": .int32(1),
                                                   "mechanism": "SCRAM-SHA-1",
                                                   "payload": .string(payload)
            ])
        
        let responseDocument = try firstDocument(in: response)
        
        try self.challenge(with: details, using: (nonce: nonce, response: responseDocument, scram: auth))
    }
    
    /// Authenticate with MongoDB Challenge Response
    /// TODO: Set a timeout for connecting
    internal func authenticate(mongoCR details: (username: String, password: String, against: String)) throws {
        // Get the server's nonce
        let response = try self.execute(command: [
                                                   "getNonce": .int32(1)
            ])
        
        // Get the server's challenge
        let document = try firstDocument(in: response)
        
        guard let nonce = document["nonce"].stringValue else {
            throw MongoAuthenticationError.AuthenticationFailure
        }
        
        // Digest our password and prepare it for sending
        var bytes = [Byte]()
        bytes.append(contentsOf: "\(details.username):mongo:\(details.password)".utf8)
        
        let digest = MD5.calculate(bytes).hexString
        let key = MD5.calculate("\(nonce)\(details.username)\(digest)".cStringBsonData).hexString
        
        // Respond to the challengge
        let successResponse = try self.execute(command: [
                                                          "authenticate": 1,
                                                          "nonce": .string(nonce),
                                                          "user": .string(details.username),
                                                          "key": .string(key)
            ])
        
        let successDocument = try firstDocument(in: successResponse)
        
        // Check for success
        guard successDocument["ok"].int32 == 1 else {
            throw InternalMongoError.IncorrectReply(reply: successResponse)
        }
    }
    
    /// Creates a new user
    /// Warning: Use an SSL socket to create someone for security sake!
    /// Warning: The standard library doesn't have SSL
    /// - parameter user: The user's username
    /// - parameter password: The plaintext password
    /// - parameter customData: The optional custom information to store
    public func create(user: String, password: String, roles: Document, customData: Document? = nil) throws {
        var command: Document = [
                                "createUser": ~user,
                                "pwd": ~password,
                             ]
        
        if let data = customData {
            command["customData"] = ~data
        }

        command["roles"] = .array(roles)
        
        let reply = try execute(command: command)
        let document = try firstDocument(in: reply)
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }

    /// Updates a user in this database with a new password, roles and optional set of custom data
    /// - parameter user: The user to udpate
    /// - parameter password: The new password
    /// - parameter roles: The roles to grant
    /// - parameter customData: The optional custom data you'll give him
    public func update(user: String, password: String, roles: Document, customData: Document? = nil) throws {
        var command: Document = [
                                    "updateUser": ~user,
                                    "pwd": ~password,
                                    ]
        
        if let data = customData {
            command["customData"] = ~data
        }
        
        command["roles"] = .array(roles)
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }
    
    /// Drops the specified user from this database
    /// - parameter user: The username from the user to drop
    public func drop(user: String) throws {
        let command: Document = [
                                    "dropUser": ~user
                                    ]
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }
    
    /// Removes all users from this database
    public func dropAllUsers() throws {
        let command: Document = [
                                    "dropAllUsersFromDatabase": .int32(1)
                                    ]

        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }
    
    /// Grants roles to a user in this database
    /// - parameter roles: The roles to grants
    /// - parameter to: The user's username to grant the roles to
    public func grant(roles: Document, to user: String) throws {
        let command: Document = [
                                    "grantRolesToUser": ~user,
                                    "roles": .array(roles)
                                    ]
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }
    
    /// Drops this database and collections
    public func drop() throws {
        let command: Document = [
                                    "dropDatabase": .int32(1)
                                    ]
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }
    
    /// Creates a new collection in this database
    /// Is used to create a collection with a cap and/or max amount of Documents
    /// Don't use it for a normal unlimited collection. Then use `db["myCollection"]` instead to create it automatically
    /// - parameter collection: The collection name
    /// - parameter cappedBytes: The max amount of bytes in here
    /// - parameter maxDocuments: The maximum amount of documents in here
    public func create(collection: String, cappedBytes capped: Int32? = nil, maxDocuments max: Int32? = nil) throws {
        var command: Document = [
                                    "create": ~collection
                                    ]

        if let capped = capped {
            command["capped"] = true
            command["size"] = ~capped
        }
        
        if let max = max {
            command["max"] = ~max
        }
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }
    
    /// Copies this database and collections to another name
    /// - parameter to: The new database name
    /// - parameter as: The optional user credentials that you'll use to authenticate in the new DB
    public func copy(to database: String, as user: (user: String, nonce: String, password: String)? = nil) throws {
        try server.copy(database: self.name, to: database, as: user)
    }
    
    /// Clones collection in the namespace from a server to this database
    /// Optionally filters data you don't want
    /// - parameter namespace: The remote namespace
    /// - parameter from: The server URI you're copying from
    /// - parameter filtering: The query you're using to filter this
    public func clone(namespace: String, from server: String, filtering filter: Query? = nil) throws {
        var command: Document = [
                                    "cloneCollection": ~namespace,
                                    "from": ~server
        ]
        
        if let filter = filter {
            command["query"] = ~filter.data
        }
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }
    
    /// Clones collection in the namespace from a server to this database
    /// Optionally filters data you don't want
    /// - parameter namespace: The remote namespace
    /// - parameter from: The server URI you're copying from
    /// - parameter filtering: The document filter you're using to filter this
    public func clone(namespace: String, from server: String, filtering filter: Document? = nil) throws {
        var command: Document = [
                                    "cloneCollection": ~namespace,
                                    "from": ~server
        ]
        
        if let filter = filter {
            command["query"] = ~filter
        }
        
        let document = try firstDocument(in: try execute(command: command))
        
        // If we're done
        if document["done"].bool == true {
            return
        }

        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }
    
    /// Clones a collection in this database to another name in this database and caps it
    /// - parameter collection: The collection to clone
    /// - parameter to: The new name to clone it to
    /// - parameter capped: The new cap
    public func clone(collection: Collection, to otherCollection: String, capped: Int32) throws {
        let command: Document = [
                                    "cloneCollectionAsCapped": ~collection.name,
                                    "toCollection": ~otherCollection,
                                    "size": ~capped
        ]
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"].int32 == 1 else {
            throw MongoError.CommandFailure
        }
    }
}