import BSON
import _MongoKittenCrypto
import Foundation
import MongoCore
import NIO

enum SASLMechanism: String, Codable {
    case scramSha1 = "SCRAM-SHA-1"
    case scramSha256 = "SCRAM-SHA-256"

    var md5Digested: Bool {
        return self == .scramSha1
    }
}

enum BinaryOrString: Codable {
    case binary(Binary)
    case string(String)
    
    public init(from decoder: Decoder) throws {
        do {
            self = try .binary(Binary(from: decoder))
        } catch {
            self = try .string(String(from: decoder))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .binary(let binary):
            try binary.encode(to: encoder)
        case .string(let string):
            try string.encode(to: encoder)
        }
    }
    
    var string: String? {
        switch self {
        case .binary(let binary):
            return String(data: binary.data, encoding: .utf8)
        case .string(let string):
            return string
        }
    }
    
    func base64Decoded() throws -> String {
        switch self {
        case .binary(let binary):
            return try (String(data: binary.data, encoding: .utf8) ?? "").base64Decoded()
        case .string(let string):
            return try string.base64Decoded()
        }
    }
}

/// A SASLStart message initiates a SASL conversation, in our case, used for SCRAM-SHA-xxx authentication.
struct SASLStart: Codable {
    private var saslStart: Int32 = 1
    let mechanism: SASLMechanism
    let payload: BinaryOrString

    init(mechanism: SASLMechanism, payload: String) {
        self.mechanism = mechanism
        self.payload = .string(payload)
    }
}

/// A generic type containing a payload and conversationID.
/// The payload contains an answer to the previous SASLMessage.
///
/// For SASLStart it contains a challenge the client needs to answer
/// For SASLContinue it contains a success or failure state
///
/// If no authentication is needed, SASLStart's reply may contain `done: true` meaning the SASL proceedure has ended
struct SASLReply: Decodable {
    let conversationId: Int32
    let done: Bool
    let payload: BinaryOrString

    init(reply: MongoServerReply) throws {
        try reply.assertOK(or: MongoAuthenticationError(reason: .anyAuthenticationFailure))
        let doc = try reply.getDocument()

        if let conversationId = doc["conversationId"] as? Int {
            self.conversationId = Int32(conversationId)
        } else if let conversationId = doc["conversationId"] as? Int32 {
            self.conversationId = conversationId
        } else {
            throw try MongoGenericErrorReply(reply: reply)
        }

        guard let done = doc["done"] as? Bool else {
            throw try MongoGenericErrorReply(reply: reply)
        }

        self.done = done

        if let payload = doc["payload"] as? String {
            self.payload = .string(payload)
        } else  if let payload = doc["payload"] as? Binary {
            self.payload = .binary(payload)
        } else {
            throw try MongoGenericErrorReply(reply: reply)
        }
    }
}

/// A SASLContinue message contains the previous conversationId (from the SASLReply to SASLStart).
/// The payload must contian an answer to the SASLReply's challenge
struct SASLContinue: Codable {
    private var saslContinue: Int32 = 1
    let conversationId: Int32
    let payload: BinaryOrString

    init(conversation: Int32, payload: String) {
        self.conversationId = conversation
        self.payload = .string(payload)
    }
}

protocol SASLHash: Hash {
    static var algorithm: SASLMechanism { get }
}

extension SHA1: SASLHash {
    static let algorithm = SASLMechanism.scramSha1
}

extension SHA256: SASLHash {
    static let algorithm = SASLMechanism.scramSha256
}

extension MongoConnection {
    /// Handles a SCRAM authentication flow
    ///
    /// The Hasher `H` specifies the hashing algorithm used with SCRAM.
    func authenticateSASL<H: SASLHash>(hasher: H, namespace: MongoNamespace, username: String, password: String) async throws {
        let context = SCRAM<H>(hasher)

        let rawRequest = try context.authenticationString(forUser: username)
        let request = Data(rawRequest.utf8).base64EncodedString()
        let command = SASLStart(mechanism: H.algorithm, payload: request)

        // NO session must be used here: https://github.com/mongodb/specifications/blob/master/source/sessions/driver-sessions.rst#when-opening-and-authenticating-a-connection
        // Forced on the current connection
        var reply = try await self.executeCodable(
            command,
            decodeAs: SASLReply.self,
            namespace: namespace,
            sessionId: nil
        )
        
        if reply.done {
            return
        }

        let preppedPassword: String

        if H.algorithm.md5Digested {
            var md5 = MD5()
            let credentials = "\(username):mongo:\(password)"
            preppedPassword = md5.hash(bytes: Array(credentials.utf8)).hexString
        } else {
            preppedPassword = password
        }

        let challenge = try reply.payload.base64Decoded()
        let rawResponse = try context.respond(toChallenge: challenge, password: preppedPassword)
        let response = Data(rawResponse.utf8).base64EncodedString()

        let next = SASLContinue(
            conversation: reply.conversationId,
            payload: response
        )

        reply = try await self.executeCodable(
            next,
            decodeAs: SASLReply.self,
            namespace: namespace,
            sessionId: nil
        )
        
        let successReply = try reply.payload.base64Decoded()
        try context.completeAuthentication(withResponse: successReply)
        
        if reply.done {
            return
        }
        
        let final = SASLContinue(
            conversation: reply.conversationId,
            payload: ""
        )

        reply = try await self.executeCodable(
            final,
            decodeAs: SASLReply.self,
            namespace: namespace,
            sessionId: nil
        )
        
        guard reply.done else {
            self.logger.error("Authentication to MongoDB failed")
            throw MongoAuthenticationError(reason: .malformedAuthenticationDetails)
        }
    }
}
