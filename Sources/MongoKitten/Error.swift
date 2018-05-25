//
//  Error.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 24-05-18.
//

import Foundation

/// An error thrown by MongoKitten
public struct MongoKittenError : Codable, Error, CustomStringConvertible {
    /// Describes the type of error that has occured
    public enum Kind : String, Codable, CustomStringConvertible {
        case invalidURI
        case unsupportedProtocol
        
        public var description: String {
            switch self {
            case .invalidURI: return "The given MongoDB connection URI is invalid"
            case .unsupportedProtocol: return "MongoKitten is unable to communicate with the server, because MongoKitten does not share a supported MongoDB protocol with the server"
            }
        }
    }
    
    /// Describes the reason why an error has occured, often providing details on how it could be fixed
    public enum Reason : String, Codable, CustomStringConvertible {
        case missingMongoDBScheme
        case uriIsMalformed
        case malformedAuthenticationDetails
        case unsupportedAuthenticationMechanism
        case invalidPort
        
        public var description: String {
            switch self {
            case .missingMongoDBScheme: return "The connection URI does not start with the 'mongodb://' scheme"
            case .uriIsMalformed: return "The URI cannot be parsed because it is malformed"
            case .malformedAuthenticationDetails: return "The authentication details in the URI are malformed and cannot be parsed"
            case .unsupportedAuthenticationMechanism: return "The given authentication mechanism is not supported by MongoKitten"
            case .invalidPort: return "The given port number is invalid"
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
