import Foundation
import NIO
import _MongoKittenCrypto

/// A SASLStart message initiates a SASL conversation, in our case, used for SCRAM-SHA-xxx authentication.
struct SASLStart: MongoDBCommand {
    private enum CodingKeys: String, CodingKey {
        case saslStart, mechanism, payload
    }
    
    enum Mechanism: String, Codable {
        case scramSha1 = "SCRAM-SHA-1"
        case scramSha256 = "SCRAM-SHA-256"
        
        var md5Digested: Bool {
            return self == .scramSha1
        }
    }
    
    typealias Reply = SASLReply
    
    let namespace: Namespace
    
    let saslStart: Int32 = 1
    let mechanism: Mechanism
    let payload: String
    
    init(namespace: Namespace, mechanism: Mechanism, payload: String) {
        self.namespace = namespace
        self.mechanism = mechanism
        self.payload = payload
    }
}

/// A generic type containing a payload and conversationID.
/// The payload contains an answer to the previous SASLMessage.
///
/// For SASLStart it contains a challenge the client needs to answer
/// For SASLContinue it contains a success or failure state
///
/// If no authentication is needed, SASLStart's reply may contain `done: true` meaning the SASL proceedure has ended
struct SASLReply: ServerReplyDecodable {
    var isSuccessful: Bool {
        return ok == 1
    }
    
    let ok: Int
    let conversationId: Int
    let done: Bool
    let payload: String
    
    func makeResult(on collection: Collection) throws -> SASLReply {
        return self
    }
}

/// A SASLContinue message contains the previous conversationId (from the SASLReply to SASLStart).
/// The payload must contian an answer to the SASLReply's challenge
struct SASLContinue: MongoDBCommand {
    private enum CodingKeys: String, CodingKey {
        case saslContinue, conversationId, payload
    }

    typealias Reply = SASLReply
    
    let namespace: Namespace
    
    let saslContinue: Int32 = 1
    let conversationId: Int
    let payload: String
    
    init(namespace: Namespace, conversation: Int, payload: String) {
        self.namespace = namespace
        self.conversationId = conversation
        self.payload = payload
    }
}

protocol SASLHash: Hash {
    static var algorithm: SASLStart.Mechanism { get }
}

extension SHA1: SASLHash {
    static let algorithm = SASLStart.Mechanism.scramSha1
}

extension SHA256: SASLHash {
    static let algorithm = SASLStart.Mechanism.scramSha256
}

extension Connection {
    /// Handles a SCRAM authentication flow
    ///
    /// The Hasher `H` specifies the hashing algorithm used with SCRAM.
    func authenticateSASL<H: SASLHash>(hasher: H, namespace: Namespace, username: String, password: String) -> EventLoopFuture<Void> {
        let context = SCRAM<H>(hasher)
        
        do {
            let rawRequest = try context.authenticationString(forUser: username)
            let request = Data(rawRequest.utf8).base64EncodedString()
            let command = SASLStart(namespace: namespace, mechanism: H.algorithm, payload: request)
            
            return self.execute(command: command).then { reply in
                if reply.done {
                    return self.eventLoop.newSucceededFuture(result: ())
                }
                
                do {
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
                        namespace: namespace,
                        conversation: reply.conversationId,
                        payload: response
                    )
                    
                    return self.execute(command: next).then { reply in
                        do {
                            let successReply = try reply.payload.base64Decoded()
                            try context.completeAuthentication(withResponse: successReply)
                            
                            if reply.done {
                                return self.eventLoop.newSucceededFuture(result: ())
                            } else {
                                let final = SASLContinue(
                                    namespace: namespace,
                                    conversation: reply.conversationId,
                                    payload: ""
                                )
                                
                                return self.execute(command: final).thenThrowing { reply in
                                    guard reply.done else {
                                        throw MongoKittenError(.authenticationFailure, reason: .malformedAuthenticationDetails)
                                    }
                                }
                            }
                        } catch {
                            return self.eventLoop.newFailedFuture(error: error)
                        }
                    }
                } catch {
                    return self.eventLoop.newFailedFuture(error: error)
                }
            }
        } catch {
            return self.eventLoop.newFailedFuture(error: error)
        }
    }
}

extension String {
    /// Decodes a base64 string into another String
    func base64Decoded() throws -> String {
        guard
            let data = Data(base64Encoded: self),
            let string = String(data: data, encoding: .utf8)
        else {
            throw MongoKittenError(.authenticationFailure, reason: .scramFailure)
        }
        
        return string
    }
}
