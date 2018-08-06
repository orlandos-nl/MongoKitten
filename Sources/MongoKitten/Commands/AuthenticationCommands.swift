import Foundation
import NIO
import _MongoKittenCrypto

struct SASLStart: MongoDBCommand {
    private enum CodingKeys: String, CodingKey {
        case saslStart, mechanism, payload
    }
    
    typealias Reply = SASLReply
    
    let namespace: Namespace
    
    let saslStart: Int32 = 1
    let mechanism = "SCRAM-SHA-1"
    let payload: String
    
    init(namespace: Namespace, payload: String) {
        self.namespace = namespace
        self.payload = payload
    }
}

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

extension Connection {
    func authenticateSASL<H: Hash>(hasher: H, namespace: Namespace, username: String, password: String) -> EventLoopFuture<Void> {
        let context = SCRAM<H>(hasher)
        
        do {
            let rawRequest = try context.authenticationString(forUser: username)
            let request = Data(rawRequest.utf8).base64EncodedString()
            let command = SASLStart(namespace: namespace, payload: request)
            
            return self.execute(command: command).then { reply in
                if reply.done {
                    return self.eventLoop.newSucceededFuture(result: ())
                }
                
                do {
                    var md5 = MD5()
                    let credentials = "\(username):mongo:\(password)"
                    let password = md5.hash(bytes: Array(credentials.utf8)).hexString
                    
                    let challenge = try reply.payload.base64Decoded()
                    let rawResponse = try context.respond(toChallenge: challenge, password: password)
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
                            
                            return self.eventLoop.newSucceededFuture(result: ())
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
