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
    internal func authenticateCR(_ username: String, password: String, namespace: MongoNamespace) async throws  {
        let nonceReply = try await self.executeCodable(
            GetNonce(),
            decodeAs: GetNonceResult.self,
            namespace: namespace,
            sessionId: nil
        )
        
        let nonce = nonceReply.nonce

        var md5 = MD5()

        let credentials = username + ":mongo:" + password
        let digest = md5.hash(bytes: Array(credentials.utf8)).hexString
        let key = nonce + username + digest
        let keyDigest = md5.hash(bytes: Array(key.utf8)).hexString

        let authenticate = AuthenticateCR(nonce: nonce, user: username, key: keyDigest)

        let authenticationReply = try await self.executeEncodable(
            authenticate,
            namespace: namespace,
            sessionId: nil
        )
        
        try authenticationReply.assertOK(
            or: MongoAuthenticationError(reason: .anyAuthenticationFailure)
        )
    }
}
