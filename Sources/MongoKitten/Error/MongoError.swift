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
    
    /// The body of this message is an invalid length
    case invalidBodyLength
    
    /// We can't do this action because we're not yet connected
    case notConnected
    
    /// The action timed out
    case timeout
    
    /// The Database command execution failed
    case commandFailure(error: Document)
    
    /// The Database command execution failed
    case commandError(error: String)
    
    /// Thrown when the initialization of a cursor, on request of the server, failed because of missing data.
    case cursorInitializationError(cursorDocument: Document)
    
    /// The MongoDB server responded with an invalid reply
    case invalidReply
    
    /// The response with the given documents is invalid
    case invalidResponse(documents: [Document])
    
    /// If you get one of these, it's probably a bug on our side. Sorry. Please file an issue at https://github.com/OpenKitten/MongoKitten/issues/new :)
    case internalInconsistency
    
    /// Unsupported operation
    case unsupportedOperations
    
    /// Invalid chunksize
    case invalidChunkSize(chunkSize: Int)
    
    /// GridFS was asked to return a negative amount of bytes
    case negativeBytesRequested(start: Int, end: Int)
    
    /// Invalid MongoDB URI
    case invalidURI(uri: String)
    
    /// The URI misses the MongoDB Schema
    case noMongoDBSchema
    
    /// No servers available to connect to
    case noServersAvailable
    
    /// Unsupported feature (Authentication mechanisms for example)
    case unsupportedFeature(String)
    
    /// GridFS had a request for data that does not exist
    case tooMuchDataRequested(contains: Int, requested: Int)
    
    /// GridFS had a request for data that had a negative index
    case negativeDataRequested
    
    /// The received Document that contains the MongoDB server build info is invalid
    case invalidBuildInfoDocument
    
    /// MD5 file hashing in GridFS failed
    case couldNotHashFile
    
    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        switch self {
        case .invalidDatabase(let name):
            return "A database with the name \"\(name ?? "")\" could not be created."
        case .invalidBase64String:
            return "Unable to decode the Base64 string"
        case .notConnected:
            return "MongoKitten is disconnected from the MongoDB server"
        case .timeout:
            return "The action timed out"
        case .commandFailure(_):
            return "The database command failed, possibly because the MongoDB server version is too low."
        case .commandError(let error):
            return "The command execution resulted in the following error: \"\(error)\""
        case .cursorInitializationError(_):
            return "Initialization of the cursor using the provided Document failed"
        case .invalidReply:
            return "The MongoDB reply was invalid"
        case .invalidResponse(_):
            return "The MongoDB server response is invalid"
        case .internalInconsistency:
            return "MongoKitten has encountered an internal error. Please file an issue at https://github.com/OpenKitten/MongoKitten/issues/new"
        case .invalidChunkSize(let chunkSize):
            return "The provided chunkSize of \(chunkSize) is invalid"
        case .negativeBytesRequested(let from, let to):
            return "GridFS has been queries for a negative amount of data. From byte #\(from) to #\(to)"
        case .invalidURI(let uri):
            return "The following MongoDB connection string is invalid \"\(uri)\""
        case .noMongoDBSchema:
            return "The MongoDB Connection string was a valid URI but didn't use the \"mongodb://\" schema"
        case .noServersAvailable:
            return "Unable to connect to the provided server(s)."
        case .unsupportedFeature(let feature):
            return "MongoKitten does not yet support the following feature: \"\(feature)\". If you really need this, please create an issue or make a PR to MongoKitten."
        case .tooMuchDataRequested(let contains, let requested):
            return "This file doesn't contain enough data to fulfill the request. Contains \(contains) bytes, the request was for \(requested) bytes"
        case .negativeDataRequested:
            return "Request for data at a negative index"
        case .invalidBuildInfoDocument:
            return "The build info document had an invalid structure"
        case .couldNotHashFile:
            return "Hashing the GridFS file with MD5 failed"
        default:
            return ""
        }
    }
}

/// Authenication failure
public enum AuthenticationError : Error {
    /// Generic error
    case authenticationFailure
    
    /// Invalid remote signature
    case serverSignatureInvalid
    
    /// Invalid credentials
    case incorrectCredentials
    
    /// Unable to parse the provided challenge
    case challengeParseError(challenge: String)
    
    /// Unable to parse the provided response
    case responseParseError(response: String)
    
    /// The nonce received by the server isn't valid
    case invalidNonce(nonce: String)
    
    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        switch self {
        case .authenticationFailure:
            return "Authentication failed due to an unknown error"
        case .incorrectCredentials:
            return "The credentials were invalid"
        case .serverSignatureInvalid:
            return "The server's signature was found invalid"
        case .challengeParseError(let challenge):
            #if Xcode
                return "The following SCRAM challenge couldn't be parsed: \"\(challenge)\""
            #else
                return "The SCRAM challenge couldn't be parsed"
            #endif
        case .responseParseError(let response):
            #if Xcode
                return "The following SCRAM response couldn't be parsed: \"\(response)\""
            #else
                return "The SCRAM response couldn't be parsed"
            #endif
        case .invalidNonce(let nonce):
            #if Xcode
                return "The following SCRAM nonce is invalid: \"\(nonce)\""
            #else
                return "The SCRAM nonce is invalid"
            #endif
        }
    }
}

/// Internal errors
internal enum InternalMongoError : Error, CustomDebugStringConvertible {
    /// Invalid message, couldn't be parsed to a Reply
    case incorrectReply(reply: ServerReply)
    
    /// The CString contains an invalid character or wasn't null-terminated.
    case invalidCString
    
    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        switch self {
        case .invalidCString:
            return "The CString contains an invalid character or wasn't null-terminated"
        case .incorrectReply(let reply):
            return "The MongoDB response wasn't expected. " + reply.documents.makeExtendedJSON().serializedString()
        }
    }
}
