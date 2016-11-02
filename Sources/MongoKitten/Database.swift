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

/// A Mongo Database. Cannot be publically initialized.
/// But you can get a database object by subscripting `Server` with a `String` as the database name
public final class Database {
    /// The `Server` that this Database is a part of
    public let server: Server
    
    /// The database's name
    public let name: String
    
    /// Are we authenticated?
    public internal(set) var isAuthenticated = true
    
    /// A cache of all collections in this Database.
    ///
    /// Mainly used for keeping track of event listeners
    private var collections = [String: Weak<Collection>]()
    
    /// Initialise this database object
    ///
    /// - parameter database: The database to use
    /// - parameter server: The `Server` on which this database exists
    public init(database: String, at server: Server) {
        self.server = server
        self.name = database.replacingOccurrences(of: ".", with: "")
    }
    
    private static let subscriptQueue = DispatchQueue(label: "org.mongokitten.database.subscriptqueue")
    
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
    internal func execute(command document: Document, until timeout: TimeInterval = 60) throws -> Message {
        let connection = try server.reserveConnection()
        
        defer {
            server.returnConnection(connection)
        }
        
        let cmd = self["$cmd"]
        let commandMessage = Message.Query(requestID: server.nextMessageID(), flags: [], collection: cmd, numbersToSkip: 0, numbersToReturn: 1, query: document, returnFields: nil)
        return try server.sendAndAwait(message: commandMessage, overConnection: connection, timeout: timeout)
    }
    
    /// All information about the `Collection`s in this `Database`
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/listCollections/#dbcmd.listCollections
    ///
    /// - parameter matching: The filter to apply when searching for this information
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - returns: A cursor to the resulting documents with collection info
    public func getCollectionInfos(matching filter: Document? = nil) throws -> Cursor<Document> {
        var request: Document = ["listCollections": 1]
        if let filter = filter {
            request["filter"] = filter
        }
        
        let reply = try execute(command: request)
        
        let result = try firstDocument(in: reply)
        
        guard let cursor = result["cursor"] as? Document, result["ok"] == 1 else {
            throw MongoError.commandFailure(error: result)
        }
        
        return try Cursor(cursorDocument: cursor, collection: self["$cmd"], chunkSize: 10, transform: { $0 })
    }
    
    /// Gets the `Collection`s in this `Database`
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    ///
    /// - parameter matching: The filter to apply when looking for Collections
    ///
    /// - returns: A `Cursor` to all `Collection`s in this `Database`
    public func listCollections(matching filter: Document? = nil) throws -> Cursor<Collection> {
        let infoCursor = try self.getCollectionInfos(matching: filter)
        return Cursor(base: infoCursor) { collectionInfo in
            return self[collectionInfo["name"] as? String ?? ""]
        }
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
        let response = try self.execute(command: ["ismaster": Int32(1)])
        
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
    private func complete(SASL payload: String, using response: Document, verifying signature: [UInt8]) throws {
        // If we failed authentication
        guard response["ok"] == 1 else {
            throw MongoAuthenticationError.incorrectCredentials
        }
        
        if response["done"] == true {
            return
        }
        
        guard let stringResponse = response["payload"] as? String else {
            throw MongoAuthenticationError.authenticationFailure
        }
        
        guard let conversationId = response["conversationId"] else {
            throw MongoAuthenticationError.authenticationFailure
        }
        
        guard let finalResponseData = Data(base64Encoded: stringResponse), let finalResponse = String(bytes: Array(finalResponseData), encoding: String.Encoding.utf8) else {
            throw MongoAuthenticationError.base64Failure
        }
        
        let dictionaryResponse = self.parse(response: finalResponse)
        
        guard let v = dictionaryResponse["v"] else {
            throw MongoAuthenticationError.authenticationFailure
        }
        
        guard let serverSignatureData = Data(base64Encoded: v) else {
            throw MongoError.invalidBase64String
        }
        
        let serverSignature = Array(serverSignatureData)
        
        guard serverSignature == signature else {
            throw MongoAuthenticationError.serverSignatureInvalid
        }
        
        let response = try self.execute(command: [
            "saslContinue": Int32(1),
            "conversationId": conversationId,
            "payload": ""
            ])
        
        guard case .Reply(_, _, _, _, _, _, let documents) = response, let responseDocument = documents.first else {
            throw InternalMongoError.incorrectReply(reply: response)
        }
        
        try self.complete(SASL: payload, using: responseDocument, verifying: serverSignature)
    }
    
    /// Respond to a challenge
    ///
    /// - parameter details: The authentication details
    /// - parameter previousInformation: The nonce, response and `SCRAMClient` instance
    ///
    /// - throws: When the authentication fails, when Base64 fails
    private func challenge(with details: (username: String, password: String, against: String), using previousInformation: (nonce: String, response: Document, scram: SCRAMClient<SHA1>)) throws {
        // If we failed the authentication
        guard previousInformation.response["ok"] == 1 else {
            throw MongoAuthenticationError.incorrectCredentials
        }
        
        // Get our ConversationID
        guard let conversationId = previousInformation.response["conversationId"] else {
            throw MongoAuthenticationError.authenticationFailure
        }
        
        // Decode the challenge
        guard let stringResponse = previousInformation.response["payload"] as? String else {
            throw MongoAuthenticationError.authenticationFailure
        }
        
        guard let stringResponseData = Data(base64Encoded: stringResponse), let decodedStringResponse = String(bytes: Array(stringResponseData), encoding: String.Encoding.utf8) else {
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
        let response = try self.execute(command: [
            "saslContinue": Int32(1),
            "conversationId": conversationId,
            "payload": payload
            ])
        
        // If we don't get a correct reply
        guard case .Reply(_, _, _, _, _, _, let documents) = response, let responseDocument = documents.first else {
            throw InternalMongoError.incorrectReply(reply: response)
        }
        
        // Complete Authentication
        try self.complete(SASL: payload, using: responseDocument, verifying: result.serverSignature)
    }
    
    /// Authenticates to this database using SASL
    ///
    /// - parameter details: The authentication details
    ///
    /// - throws: When failing authentication, being unable to base64 encode or failing to send/receive messages
    internal func authenticate(SASL details: (username: String, password: String, against: String)) throws {
        let nonce = randomNonce()
        
        let auth = SCRAMClient<SHA1>()
        
        let authPayload = try auth.authenticate(details.username, usingNonce: nonce)
        
        let payload = Data(bytes: authPayload.cStringBytes).base64EncodedString()
        
        let response = try self.execute(command: [
            "saslStart": Int32(1),
            "mechanism": "SCRAM-SHA-1",
            "payload": payload
            ])
        
        let responseDocument = try firstDocument(in: response)
        
        try self.challenge(with: details, using: (nonce: nonce, response: responseDocument, scram: auth))
    }
    
    /// Authenticates to this database using MongoDB Challenge Response
    ///
    /// - parameter details: The authentication details
    ///
    /// - throws: When failing authentication, being unable to base64 encode or failing to send/receive messages
    internal func authenticate(mongoCR details: (username: String, password: String, against: String)) throws {
        // Get the server's nonce
        let response = try self.execute(command: [
            "getnonce": Int32(1)
            ])
        
        // Get the server's challenge
        let document = try firstDocument(in: response)
        
        guard let nonce = document["nonce"] as? String else {
            throw MongoAuthenticationError.authenticationFailure
        }
        
        // Digest our password and prepare it for sending
        var bytes = [UInt8]()
        bytes.append(contentsOf: "\(details.username):mongo:\(details.password)".utf8)
        
        let digest = MD5.hash(bytes)
        let key = MD5.hash([UInt8]("\(nonce)\(details.username)\(digest)".utf8)).hexString
        
        // Respond to the challengge
        let successResponse = try self.execute(command: [
            "authenticate": 1,
            "nonce": nonce,
            "user": details.username,
            "key": key
            ])
        
        let successDocument = try firstDocument(in: successResponse)
        
        // Check for success
        guard successDocument["ok"] == 1 else {
            throw InternalMongoError.incorrectReply(reply: successResponse)
        }
    }
}

/// Additional functionality
extension Database {
    /// Creates a new user
    ///
    /// Warning: Use an SSL socket to create someone for security sake!
    /// Warning: The standard library doesn't have SSL
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/createUser/#dbcmd.createUser
    ///
    /// - parameter user: The user's username
    /// - parameter password: The plaintext password
    /// - parameter roles: The roles document as specified in the additional information
    /// - parameter customData: The optional custom information to store
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func createUser(_ user: String, password: String, roles: Document, customData: Document? = nil) throws {
        var command: Document = [
            "createUser": user,
            "pwd": password,
            ]
        
        if let data = customData {
            command["customData"] = data
        }
        
        command["roles"] = roles
        
        let reply = try execute(command: command)
        let document = try firstDocument(in: reply)
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Updates a user in this database with a new password, roles and optional set of custom data
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/updateUser/#dbcmd.updateUser
    ///
    /// - parameter user: The user to udpate
    /// - parameter password: The new password
    /// - parameter roles: The roles to grant
    /// - parameter customData: The optional custom data you'll give him
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func update(user username: String, password: String, roles: Document, customData: Document? = nil) throws {
        var command: Document = [
            "updateUser": username,
            "pwd": password,
            ]
        
        if let data = customData {
            command["customData"] = data
        }
        
        command["roles"] = roles
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Removes the specified user from this database
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/dropUser/#dbcmd.dropUser
    ///
    /// - parameter user: The username from the user to drop
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func drop(user username: String) throws {
        let command: Document = [
            "dropUser": username
        ]
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Removes all users from this database
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/dropAllUsersFromDatabase/#dbcmd.dropAllUsersFromDatabase
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func dropAllUsers() throws {
        let command: Document = [
            "dropAllUsersFromDatabase": Int32(1)
        ]
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Grants roles to a user in this database
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/grantRolesToUser/#dbcmd.grantRolesToUser
    ///
    /// - parameter roles: The roles to grants
    /// - parameter user: The user's username to grant the roles to
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func grant(roles roleList: Document, to user: String) throws {
        let command: Document = [
            "grantRolesToUser": user,
            "roles": roleList
        ]
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Drops this database and it's collections
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/dropDatabase/#dbcmd.dropDatabase
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func drop() throws {
        let command: Document = [
            "dropDatabase": Int32(1)
        ]
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Creates a new collection explicitly.
    ///
    /// Because MongoDB creates a collection implicitly when the collection is first referenced in a
    /// command, this method is used primarily for creating new collections that use specific
    /// options. For example, you use `createCollection()` to create a capped collection, or to
    /// create a new collection that uses document validation. `createCollection()` is also used to
    /// pre-allocate space for an ordinary collection
    ///
    /// For more information and a full list of options: https://docs.mongodb.com/manual/reference/command/create/
    ///
    /// - parameter name: The name of the collection to create.
    /// - parameter options: Optionally, configuration options for creating this collection.
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func createCollection(_ name: String, options: Document? = nil) throws {
        var command: Document = ["create": name]
        
        if let options = options {
            for option in options {
                command[option.key] = option.value
            }
        }
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Copies this `Database` and `Collection`s to another `Database`
    ///
    /// - parameter database: The new database name
    /// - parameter user: The optional user credentials that you'll use to authenticate in the new DB
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func copy(toDatabase database: String, asUser user: (user: String, nonce: String, password: String)? = nil) throws {
        try server.copy(database: self.name, to: database, as: user)
    }
    
    /// Clones collection in the namespace from a server to this database
    /// Optionally filters data you don't want
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/cloneCollection/#dbcmd.cloneCollection
    ///
    /// - parameter namespace: The remote namespace
    /// - parameter server: The server URI you're copying from
    /// - parameter filter: The query you're using to filter this
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(toNamespace ns: String, fromServer server: String, filteredBy filter: Query? = nil) throws {
        var command: Document = [
            "cloneCollection": ns,
            "from": server
        ]
        
        if let filter = filter {
            command["query"] = filter.queryDocument
        }
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Clones collection in the namespace from a server to this database
    /// Optionally filters data you don't want
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/cloneCollection/#dbcmd.cloneCollection
    ///
    /// - parameter namespace: The remote namespace
    /// - parameter from: The server URI you're copying from
    /// - parameter filtering: The document filter you're using to filter this
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(toNamespace ns: String, fromServer server: String, filteredBy filter: Document? = nil) throws {
        var command: Document = [
            "cloneCollection": ns,
            "from": server
        ]
        
        if let filter = filter {
            command["query"] = filter
        }
        
        let document = try firstDocument(in: try execute(command: command))
        
        // If we're done
        if document["done"] == true {
            return
        }
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Clones a collection in this database to another name in this database and caps it
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/cloneCollectionAsCapped/#dbcmd.cloneCollectionAsCapped
    ///
    /// - parameter collection: The collection to clone
    /// - parameter otherCollection: The new name to clone it to
    /// - parameter capped: The new cap
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func clone(collection instance: Collection, named otherCollection: String, cappedTo capped: Int32) throws {
        let command: Document = [
            "cloneCollectionAsCapped": instance.name,
            "toCollection": otherCollection,
            "size": Int32(capped).makeBsonValue()
        ]
        
        let document = try firstDocument(in: try execute(command: command))
        
        guard document["ok"] == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
}

extension Database : CustomStringConvertible {
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
