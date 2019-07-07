public struct MongoAuthenticationError: Error, CustomStringConvertible {
    public enum Reason: String, Codable, CustomStringConvertible, Equatable {
        case missingServerHandshake
        case anyAuthenticationFailure
        case unsupportedAuthenticationMechanism
        case malformedAuthenticationDetails
        case scramFailure
        case unexpectedSASLPhase
        case internalError

        public var description: String {
            switch self {
            case .missingServerHandshake:
                return "The handshake did not successfully complete, and no fallback was available"
            case .anyAuthenticationFailure:
                return "Authentication failed, the credentials, algorithm or target collection is incorrect"
            case .unsupportedAuthenticationMechanism:
                return "The current version of this driver does not support the selected authentication mechanism"
            case .malformedAuthenticationDetails:
                return "The authentication details in the URI are malformed and cannot be parsed"
            case .scramFailure:
                return "Authentication failed due to the wrong credentials or authentication collection being provided"
            case .unexpectedSASLPhase:
                return "The server's SASL phase moved to an unexpected state, causing an error"
            case .internalError:
                return "The driver's internal state had an unexpected value"
            }
        }
    }

    public let description = "An error occurred while connecting to MongoDB"
    public let reason: Reason

    internal init(reason: Reason) {
        self.reason = reason
    }
}

internal struct OptionalUnwrapFailure: Error, CustomStringConvertible {
    let description = "An optional was unwrapped but `nil` was found"
}

/// A reply from the server, indicating an error
public struct MongoGenericErrorReply: Error, Codable, Equatable {
    public let ok: Int
    public let errorMessage: String?
    public let code: Int?
    public let codeName: String?

    private enum CodingKeys: String, CodingKey {
        case ok, code, codeName
        case errorMessage = "errmsg"
    }
}
