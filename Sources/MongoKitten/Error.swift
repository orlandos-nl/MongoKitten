//
//  Error.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 24-05-18.
//

import Foundation

/// An error thrown by MongoKitten
public struct MongoKittenError: Codable, Error, CustomStringConvertible, Equatable {
    /// Describes the type of error that has occured
    public enum Kind: String, Codable, CustomStringConvertible, Equatable {
        /// The given MongoDB connection URI is invalid
        case invalidURI
        
        /// MongoKitten was unable ot authenticate
        case authenticationFailure
        
        /// MongoKitten is unable to communicate with the server, because MongoKitten does not share a supported MongoDB protocol with the server
        case unsupportedProtocol
        
        /// MongoKitten is unable to connect to the server
        case unableToConnect
        
        /// MongoDB replied with an error reply indicating the command failed
        case commandFailure
        
        /// An error occurred when parsing a reply message from MongoDB
        case protocolParsingError
        
        /// The aggregate failed because the results mismatched MongoKitten's expectations
        case unexpectedAggregateResults
        
        /// The cursor cannot get more elements
        case cannotGetMore
        
        /// A command for the requested action could not be formed
        case cannotFormCommand
        
        /// A feature you're trying to use is unsupported by your version of MongoDB
        case unsupportedFeatureByServer
        
        /// A value was unexpectedly nil
        case unexpectedNil
        
        public var description: String {
            switch self {
            case .authenticationFailure: return "MongoKitten was unable ot authenticate"
            case .invalidURI: return "The given MongoDB connection URI is invalid"
            case .unsupportedProtocol: return "MongoKitten is unable to communicate with the server, because MongoKitten does not share a supported MongoDB protocol with the server"
            case .unableToConnect: return "MongoKitten is unable to connect to the server"
            case .commandFailure:
                // FIXME: This doesn't seem like a good error
                return "MongoDB replied with an error reply indicating the command failed"
            case .protocolParsingError:
                return "An error occurred when parsing a reply message from MongoDB"
            case .unexpectedAggregateResults:
                return "The aggregate failed because the results mismatched MongoKitten's expectations"
            case .cannotGetMore: return "The cursor cannot get more elements"
            case .cannotFormCommand: return "A command for the requested action could not be formed"
            case .unexpectedNil: return "A value was unexpectedly nil"
            case .unsupportedFeatureByServer: return "A feature you're trying to use is unsupported by your version of MongoDB"
            }
        }
    }
    
    /// Describes the reason why an error has occured, often providing details on how it could be fixed
    public enum Reason: String, Codable, CustomStringConvertible, Equatable {
        /// The connection URI does not start with the 'mongodb://' scheme
        case missingMongoDBScheme
        
        /// The URI cannot be parsed because it is malformed
        case uriIsMalformed
        
        /// The authentication details in the URI are malformed and cannot be parsed
        case malformedAuthenticationDetails
        
        /// The given authentication mechanism is not supported by MongoKitten
        case unsupportedAuthenticationMechanism
        
        /// The reason for the error was internal
        case internalError
        
        /// The operation exceeded the 16MB command limit
        case commandSizeTooLarge
        
        /// SCRAM protocol failure
        case scramFailure
        
        /// The connection to MongoDB was closed
        case connectionClosed
        
        /// The handshake was not completed
        case handshakeFailed
        
        /// The given port number is invalid
        case invalidPort
        
        /// No host was specified
        case noHostSpecified
        
        /// A target database was not specified
        case noTargetDatabaseSpecified
        
        /// The target server is not writable
        case hostNotWritable
        
        /// One Document was expected but none were returned
        case noResultDocument
        
        /// One Document was expected but multiple were returned
        case multipleResultDocuments
        
        /// The value found in the result cursor did not match the expectation
        case unexpectedValue
        
        /// The cursor has been drained, which means there are no more elements left to get
        case cursorDrained
        
        /// The cursor was intentionally closed and will not yield more results
        case cursorClosed
        
        /// There is nothing to do with the given parameters
        case nothingToDo
        
        /// The server replied with an opcode that is not supported by MongoKitten
        case unsupportedOpCode
        
        /// Index creation failed
        case indexCreationFailed
        
        /// The MongoDB server does not support read concerns
        case readConcernUnsupported
        
        /// The MongoDB server does not support write concerns
        case writeConcernUnsupported
        
        /// No host was newly known
        case noAvailableHosts
        
        public var description: String {
            switch self {
            case .missingMongoDBScheme: return "The connection URI does not start with the 'mongodb://' scheme"
            case .uriIsMalformed: return "The URI cannot be parsed because it is malformed"
            case .scramFailure: return "SCRAM protocol failed, the communication was incorrect"
            case .malformedAuthenticationDetails: return "The authentication details in the URI are malformed and cannot be parsed"
            case .unsupportedAuthenticationMechanism: return "The given authentication mechanism is not supported by MongoKitten"
            case .internalError: return "The reason for the error was internal"
            case .invalidPort: return "The given port number is invalid"
            case .noHostSpecified: return "No host was specified"
            case .hostNotWritable: return "The target server is not writable"
            case .commandSizeTooLarge: return "The operation exceeded the 16MB command limit"
            case .noTargetDatabaseSpecified: return "A target database was not specified"
            case .connectionClosed: return "The connection to MongoDB was closed"
            case .noResultDocument: return "One Document was expected but none were returned"
            case .multipleResultDocuments: return "One Document was expected but multiple were returned"
            case .unexpectedValue: return "The value found in the result cursor did not match the expectation"
            case .cursorDrained: return "The cursor has been drained, which means there are no more elements left to get"
            case .cursorClosed: return "The cursor was intentionally closed and will not yield more results"
            case .nothingToDo: return "There is nothing to do with the given parameters"
            case .unsupportedOpCode: return "The server replied with an opcode that is not supported by MongoKitten"
            case .indexCreationFailed: return "There was a failure whilst creating the index."
            case .readConcernUnsupported: return "The MongoDB server does not support read concerns"
            case .writeConcernUnsupported: return "The MongoDB server does not support read concerns"
            case .noAvailableHosts: return "No host was newly known"
            case .handshakeFailed: return "The handshake was not completed"
            }
        }
    }
    
    /// - parameter kind: The error kind. See the documentation on `MongoKittenError.Kind` for details
    /// - parameter reason: If there are multiple reasons why an error may be thrown, details on the reason. See `MongoKittenError.Reason`.
    internal init(_ kind: Kind, reason: Reason?) {
        self.kind = kind
        self.reason = reason
    }
    
    internal init(_ reply: GenericErrorReply) {
        self.kind = .commandFailure
        self.errorReply = reply
    }
    
    /// The error kind. See the documentation on `MongoKittenError.Kind` for details
    public private(set) var kind: Kind
    
    /// If there are multiple reasons why an error may be thrown, details on the reason. See `MongoKittenError.Reason`.
    public private(set) var reason: Reason?
    
    /// The MongoDB error reply that caused the error
    public private(set) var errorReply: GenericErrorReply?
    
    public var description: String {
        if let errorReply = errorReply {
            return "\(kind): \(errorReply.errorMessage ?? "unknown")"
        } else if let reason = reason {
            return "\(kind): \(reason)"
        } else {
            return "\(kind)"
        }
    }
}
