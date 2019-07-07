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
    public let description = "An error occurred while parsing a MongoMessage"

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
    public let description = "An error occurred while serializing a MongoMessage"

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
    public let description = "The given MongoDB connection URI is invalid"
}

internal struct MongoOptionalUnwrapFailure: Error, CustomStringConvertible {
    let description = "An optional was unwrapped but `nil` was found"
}

public struct MongoError: Error {
    public enum Kind: String, Codable, CustomStringConvertible, Equatable {
        case authenticationFailure
        case cannotGetMore
        case cannotConnect
        case invalidResponse
        case cannotCloseCursor
        case queryFailure

        public var description: String {
            switch self {
            case .cannotGetMore: return "Unable to get more results from the cursor"
            case .authenticationFailure: return "Authentication to MongoDB failed"
            case .invalidResponse: return "The response contained unexpected or no data"
            case .cannotCloseCursor: return "Unable to close the cursor"
            case .cannotConnect: return ""
            case .queryFailure: return ""
            }
        }
    }

    public enum Reason: String, Codable, CustomStringConvertible, Equatable {
        case internalError
        case unexpectedSASLPhase
        case scramFailure
        case missingReplyDocument
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
            case .missingReplyDocument: return ""
            case .noHostSpecified: return ""
            case .noAvailableHosts: return ""
            case .handshakeFailed: return ""
            case .connectionClosed: return ""
            case .invalidReplyType: return ""
            }
        }
    }

    public let kind: Kind
    public let reason: Reason?

    public init(_ kind: Kind, reason: Reason?) {
        self.kind = kind
        self.reason = reason
    }
}
