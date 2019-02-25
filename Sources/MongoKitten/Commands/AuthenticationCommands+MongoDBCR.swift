import BSON

#if canImport(_MongoKittenCrypto)
import _MongoKittenCrypto
#endif

struct GetNonce: MongoDBCommand {
    private enum CodingKeys: String, CodingKey {
        case getNonce
    }
    
    typealias Reply = GetNonceResult
    typealias ErrorReply = ReadErrorReply
    
    let namespace: Namespace
    let getNonce: Int32 = 1
    
    func checkValidity(for maxWireVersion: WireVersion) throws {}
    
    init(namespace: Namespace) {
        self.namespace = namespace
    }
}

struct AuthenticateCR: MongoDBCommand {
    private enum CodingKeys: String, CodingKey {
        case authenticate, nonce, user, key
    }
    
    typealias Reply = OK
    typealias ErrorReply = ReadErrorReply
    
    let namespace: Namespace
    let authenticate: Int32 = 1
    let nonce: String
    let user: String
    let key: String
    
    func checkValidity(for maxWireVersion: WireVersion) throws {}
    
    init(namespace: Namespace, nonce: String, user: String, key: String) {
        self.namespace = namespace
        self.nonce = nonce
        self.user = user
        self.key = key
    }
}

struct GetNonceResult: ServerReplyDecodableResult {
    var isSuccessful: Bool { return true }
    let nonce: String
    
    func makeResult(on collection: Collection) throws -> String {
        return nonce
    }
}

extension Connection {
    func authenticateCR(_ username: String, password: String, namespace: Namespace) -> EventLoopFuture<Void> {
        return self._execute(command: GetNonce(namespace: namespace), session: nil, transaction: nil).then { reply -> EventLoopFuture<Void> in
            do {
                let nonce = try GetNonceResult(reply: reply).nonce
                
                var md5 = MD5()
                
                let credentials = username + ":mongo:" + password
                let digest = md5.hash(bytes: Array(credentials.utf8)).hexString
                let key = nonce + username + digest
                let keyDigest = md5.hash(bytes: Array(key.utf8)).hexString
                
                let authenticate = AuthenticateCR(namespace: namespace, nonce: nonce, user: username, key: keyDigest)
                
                return self._execute(command: authenticate, session: nil, transaction: nil).thenThrowing { reply in
                    guard try OK(reply: reply).isSuccessful else {
                        throw MongoKittenError(try GenericErrorReply(reply: reply))
                    }
                }
            } catch {
                return self.eventLoop.newFailedFuture(error: error)
            }
        }
    }
}
