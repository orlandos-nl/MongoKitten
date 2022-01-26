public struct MongoProtocolParsingError: Error, Codable, CustomStringConvertible {
    public enum Reason: String, Codable, CustomStringConvertible, Equatable {
        case unsupportedOpCode
        case unexpectedValue
        case missingDocumentBody

        public var description: String {
            switch self {
            case .unexpectedValue:
                return "The value found in the result cursor did not match the expectation"
            case .unsupportedOpCode:
                return "The server replied with an opcode that is not supported by MongoKitten"
            case .missingDocumentBody:
                return "A partial Document was received, but not the entire Document's body could be read."
            }
        }
    }

    public let reason: Reason
    public private(set) var description = "An error occurred while parsing a MongoMessage"

    public init(reason: Reason) {
        self.reason = reason
    }
}

public struct MongoProtocolSerializationError: Error, Codable, CustomStringConvertible {
    public enum Reason: String, Codable, CustomStringConvertible, Equatable {
        case commandSizeTooLarge
        case unexpectedOpCode
        case unsupportedOpCode
        case missingCommandSection

        public var description: String {
            switch self {
            case .missingCommandSection:
                return "An OP_MSG was sent without a command"
            case .unexpectedOpCode:
                return "A message was attempted serialization, but the OpCode mismatched with the serialization function"
            case .unsupportedOpCode:
                return "The server replied with an opcode that is not supported by MongoKitten"
            case .commandSizeTooLarge:
                return "The operation exceeded the 16MB command limit"
            }
        }
    }

    public let reason: Reason
    public private(set) var description = "An error occurred while serializing a MongoMessage"

    public init(reason: Reason) {
        self.reason = reason
    }
}

public struct MongoInvalidUriError: Error, Codable, CustomStringConvertible {
    public enum Reason: String, Codable, CustomStringConvertible, Equatable {
        case srvCannotSpecifyPort
        case missingMongoDBScheme
        case uriIsMalformed
        case malformedAuthenticationDetails
        case unsupportedAuthenticationMechanism
        case srvNeedsOneHost
        case invalidPort

        public var description: String {
            switch self {
            case .missingMongoDBScheme:
                return "The connection URI does not start with the 'mongodb://' scheme"
            case .uriIsMalformed:
                return "The URI cannot be parsed because it is malformed"
            case .malformedAuthenticationDetails:
                return "The authentication details in the URI are malformed and cannot be parsed"
            case .unsupportedAuthenticationMechanism:
                return "The given authentication mechanism is not supported by MongoKitten"
            case .invalidPort:
                return "The given port number is invalid"
            case .srvCannotSpecifyPort:
                return "MongoDB+SRV URIs are not allowed to specify a port"
            case .srvNeedsOneHost:
                return "SRV URIs can only have one host, no more, no less"
            }
        }
    }

    public let reason: Reason
    public private(set) var description = "The given MongoDB connection URI is invalid"
}

internal struct MongoOptionalUnwrapFailure: Error, CustomStringConvertible {
    let description = "An optional was unwrapped but `nil` was found"
}

public struct MongoError: Error, CustomStringConvertible, CustomDebugStringConvertible {
    public enum Kind: String, Codable, CustomStringConvertible, Equatable {
        case authenticationFailure
        case cannotGetMore
        case cannotConnect
        case invalidResponse
        case cannotCloseCursor
        case queryFailure
        case queryTimeout

        public var description: String {
            switch self {
            case .cannotGetMore: return "Unable to get more results from the cursor"
            case .authenticationFailure: return "Authentication to MongoDB failed"
            case .invalidResponse: return "The response contained unexpected or no data"
            case .cannotCloseCursor: return "Unable to close the cursor"
            case .cannotConnect: return "No hosts could be connected with, therefore no queries can be sent at the moment"
            case .queryFailure: return "The query sent failed"
            case .queryTimeout: return "The query timed out"
            }
        }
    }

    public enum Reason: String, Codable, CustomStringConvertible, Equatable {
        case internalError
        case unexpectedSASLPhase
        case scramFailure
        case alreadyClosed
        case cursorDrained
        case noHostSpecified
        case noAvailableHosts
        case handshakeFailed
        case connectionClosed
        case invalidReplyType

        public var description: String {
            switch self {
            case .unexpectedSASLPhase: return "A message was received that didn't met the expectation of the SASL mechanism"
            case .internalError: return "A MongoKitten internal error occurred"
            case .scramFailure: return "The SCRAM mechanism rejected the credentials, login failed."
            case .cursorDrained: return "The cursor is fully drained"
            case .alreadyClosed: return "The cursor was already closed"
            case .noHostSpecified: return "No hosts listed in the connection string"
            case .noAvailableHosts: return "The connection string could not be used to connect to a host"
            case .handshakeFailed: return "MongoDB never sent a handshake"
            case .connectionClosed: return "The connection was closed, therefore errors could not be executed. This error may occur during rediscovery if the server isn't available"
            case .invalidReplyType: return "A protocol reply error occurred, rendering the connection unstable. MongoKitten will shut this connection down."
            }
        }
    }

    public let kind: Kind
    public let reason: Reason?

    public init(_ kind: Kind, reason: Reason?) {
        self.kind = kind
        self.reason = reason
    }
    
    public var recommendedSolution: String {
        guard let reason = reason else {
            return "File a report on https://github.com/OpenKitten/MongoKitten/"
        }
        
        switch reason {
        case .unexpectedSASLPhase, .handshakeFailed, .invalidReplyType:
            return """
            - Check if SSL is enabled if required, MongoDB Atlas requires this
            - Check if SRV is used for MongoDB atlas.
            - When intentionally not using SRV, make sure that the hosts in the connection string are correct
            - File a report on https://github.com/OpenKitten/MongoKitten/
            """
        case .scramFailure:
            return """
            - Check your credentials
            - Check the used `authSource` . If it's not set, try adding `authSource=true` to your parameters
            - Check the used `authMechanism` . MongoKitten can detect it automatically in most scenario's
            """
        case .connectionClosed:
            return """
            - MongoKitten will attempt to reconnect. If this keeps failing, file a report on https://github.com/OpenKitten/MongoKitten/
            - Check if your host is still online and not undergoing maintenance
            - Check if the SSL settings are enabled if needed
            
            Note:
            This error may be meaningless if the maintenance is planned.
            If other (primary) hosts are up, this error indicates that the connection is still down and may be safely ignored.
            """
        case .cursorDrained:
            return """
            - If you're trying to drain a cursor manually, make sure you check its `isDrained` property
            """
        case .alreadyClosed:
            return """
            - A cursor can only be closed once. Make sure you check the `isClosed` property on a cursor and don't call the function twice.
            """
        case .noHostSpecified:
            return """
            - Check if your connection string is correctly formatted. See: http://docs.mongodb.org/manual/reference/connection-string
            """
        case .noAvailableHosts:
            return """
            - Check if your hosts are online, not undergoing maintenance
            - Check your connection strings for any errors in configuration
            - Check if your server is whitelisted when using MongoDB atlas
            - If using MongoDB atlas, make sure you're connecting with SRV
            """
        case .internalError:
            return """
            - An internal MongoKitten error occurred, file a report on https://github.com/OpenKitten/MongoKitten/
            """
        }
    }
    
    public var debugDescription: String { description }
    public var description: String {
        "\(kind.description): \(reason?.description ?? "Unknown reason")\nSolution(s):\n\(recommendedSolution)"
    }
}
