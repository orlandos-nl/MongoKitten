import BSON
import _MongoKittenCrypto
import MongoCore
import NIO

fileprivate struct GetNonce: Encodable {
    let getnonce: Int32 = 1
}

fileprivate struct GetNonceResult: Decodable {
    let nonce: String
}

fileprivate struct AuthenticateCR: Encodable {
    let authenticate: Int32 = 1
    let nonce: String
    let user: String
    let key: String

    public init(nonce: String, user: String, key: String) {
        self.nonce = nonce
        self.user = user
        self.key = key
    }
}

extension MongoConnection {
    func authenticateCR(_ username: String, password: String, namespace: MongoNamespace) -> EventLoopFuture<Void> {
        return self.executeCodable(
            GetNonce(),
            namespace: namespace,
            sessionId: nil
        ).flatMap { reply -> EventLoopFuture<Void> in
            do {
                let reply = try GetNonceResult(reply: reply)
                let nonce = reply.nonce

                var md5 = MD5()

                let credentials = username + ":mongo:" + password
                let digest = md5.hash(bytes: Array(credentials.utf8)).hexString
                let key = nonce + username + digest
                let keyDigest = md5.hash(bytes: Array(key.utf8)).hexString

                let authenticate = AuthenticateCR(nonce: nonce, user: username, key: keyDigest)

                return self.executeCodable(
                    authenticate,
                    namespace: namespace,
                    sessionId: nil
                ).flatMapThrowing { reply in
                    try reply.assertOK(or: MongoAuthenticationError(reason: .anyAuthenticationFailure))
                }
            } catch {
                return self.eventLoop.makeFailedFuture(error)
            }
        }
    }
}
