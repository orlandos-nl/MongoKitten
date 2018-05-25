//
//  Error.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 24-05-18.
//

import Foundation

/// An error thrown by MongoKitten
public struct MongoKittenError : Codable, Error, CustomStringConvertible, Equatable {
    /// Describes the type of error that has occured
    public enum Kind : String, Codable, CustomStringConvertible, Equatable {
        case invalidURI
        case unsupportedProtocol
        case unableToConnect
        case commandFailure
        
        public var description: String {
            switch self {
            case .invalidURI: return "The given MongoDB connection URI is invalid"
            case .unsupportedProtocol: return "MongoKitten is unable to communicate with the server, because MongoKitten does not share a supported MongoDB protocol with the server"
            case .unableToConnect: return "MongoKitten is unable to connect to the server"
            case .commandFailure:
                // FIXME: This doesn't seem like a good error
                return "MongoDB replied with an error reply indicating the command failed"
            }
        }
    }
    
    /// Describes the reason why an error has occured, often providing details on how it could be fixed
    public enum Reason : String, Codable, CustomStringConvertible, Equatable {
        case missingMongoDBScheme
        case uriIsMalformed
        case malformedAuthenticationDetails
        case unsupportedAuthenticationMechanism
        case invalidPort
        case noHostSpecified
        case noTargetDatabaseSpecified
        
        public var description: String {
            switch self {
            case .missingMongoDBScheme: return "The connection URI does not start with the 'mongodb://' scheme"
            case .uriIsMalformed: return "The URI cannot be parsed because it is malformed"
            case .malformedAuthenticationDetails: return "The authentication details in the URI are malformed and cannot be parsed"
            case .unsupportedAuthenticationMechanism: return "The given authentication mechanism is not supported by MongoKitten"
            case .invalidPort: return "The given port number is invalid"
            case .noHostSpecified: return "No host was specified"
            case .noTargetDatabaseSpecified: return "A target database was not specified"
            }
        }
    }
    
    /// - parameter kind: The error kind. See the documentation on `MongoKittenError.Kind` for details
    /// - parameter reason: If there are multiple reasons why an error may be thrown, details on the reason. See `MongoKittenError.Reason`.
    internal init(_ kind: Kind, reason: Reason?) {
        self.kind = kind
        self.reason = reason
    }
    
    /// The error kind. See the documentation on `MongoKittenError.Kind` for details
    public private(set) var kind: Kind
    
    /// If there are multiple reasons why an error may be thrown, details on the reason. See `MongoKittenError.Reason`.
    public private(set) var reason: Reason?
    
    public var description: String {
        if let reason = reason {
            return "\(kind): \(reason)"
        } else {
            return "\(kind)"
        }
    }
}
