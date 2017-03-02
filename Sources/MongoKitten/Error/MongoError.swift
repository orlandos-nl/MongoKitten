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
import struct BSON.Document

/// All MongoDB errors
public enum MongoError : Error {
    /// Can't create database with name
    case invalidDatabase(String?)
    
    /// Can't deocde base64
    case invalidBase64String
    
    /// Can't connect to the MongoDB Server
    case mongoDatabaseUnableToConnect
    
    /// Can't connect since we're already connected
    case mongoDatabaseAlreadyConnected
    
    /// Can't disconnect the socket
    case cannotDisconnect
    
    /// The body of this message is an invalid length
    case invalidBodyLength
    
    /// -
    case invalidAction
    
    /// We can't do this action because we're not yet connected
    case notConnected
    
    /// Can't insert given documents
    case insertFailure(documents: [Document], error: Document?)
    
    /// Can't query for documents matching given query
    case queryFailure(query: Document, error: Document?)
    
    /// Can't update documents with the given selector and update
    case updateFailure(updates: [(filter: Query, to: Document, upserting: Bool, multiple: Bool)], error: Document?)
    
    /// Can't remove documents matching the given query
    case removeFailure(removals: [(filter: Query, limit: Int32)], error: Document?)
    
    /// Can't find a handler for this reply
    case handlerNotFound
    
    /// -
    case timeout
    
    /// -
    case commandFailure(error: Document)
    
    /// -
    case commandError(error: String)
    
    /// Thrown when the initialization of a cursor, on request of the server, failed because of missing data.
    case cursorInitializationError(cursorDocument: Document)
    
    /// -
    case invalidReply
    
    /// The response with the given documents is invalid
    case invalidResponse(documents: [Document])
    
    /// If you get one of these, it's probably a bug on our side. Sorry. Please file an issue at https://github.com/OpenKitten/MongoKitten/issues/new :)
    case internalInconsistency
    
    /// -
    case unsupportedOperations
    
    /// -
    case invalidChunkSize(chunkSize: Int)
    
    /// GridFS was asked to return a negative amount of bytes
    case negativeBytesRequested(start: Int, end: Int)
    
    /// Invalid MongoDB URI
    case invalidURI(uri: String)
    
    /// The URI misses the MongoDB Schema
    case noMongoDBSchema
    
    /// No servers available to connect to
    case noServersAvailable
    
    /// Unsupported feature (Authentication for example)
    case unsupportedFeature(String)
    
    /// GridFS had a request for data that does not exist
    case tooMuchDataRequested(contains: Int, requested: Int)
    
    /// GridFS had a request for data that had a negative index
    case negativeDataRequested
    
    /// The received Document that contains the MongoDB server build info is invalid
    case invalidBuildInfoDocument
    
    /// MD5 file hashing in GridFS failed
    case couldNotHashFile
}

/// Authenication failure
public enum MongoAuthenticationError : Error {
    /// Unable to decode Base64
    case base64Failure
    
    /// Generic error
    case authenticationFailure
    
    /// Invalid remote signature
    case serverSignatureInvalid
    
    /// Invalid credentials
    case incorrectCredentials
}

/// Internal errors
internal enum InternalMongoError : Error {
    /// Invalid message, couldn't be parsed to a Reply
    case incorrectReply(reply: Message)
    
    /// -
    case invalidCString
}
