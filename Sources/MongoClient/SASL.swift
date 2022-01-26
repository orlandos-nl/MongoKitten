import BSON
import _MongoKittenCrypto
import Foundation

/// Used by the SCRAM helper to keep track of the current state and the previous state's relevant parameters
fileprivate enum ProgressState {
    case none
    case challenge(user: String, nonce: String)
    case verify(signature: [UInt8])
}

/// A thread-safe global cache that all MongoDB clients can use to reduce computational cost of authentication
///
/// By caching the proof of being auhtenticated.
fileprivate final class MongoCredentialsCache {
    fileprivate static let `default` = MongoCredentialsCache()

    private init() {}

    private var _cache = [String: Credentials]()
    private let lock = NSRecursiveLock()

    internal subscript(password: String, iterations: Int32, salt: String) -> Credentials? {
        get {
            lock.lock()
            defer { lock.unlock() }

            let key = "\(password)\(iterations)\(salt)"
            var sha1 = SHA1()
            let keuHash = sha1.hash(key, count: key.count).hexString
            return _cache[keuHash]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            
            let key = "\(password)\(iterations)\(salt)"
            var sha1 = SHA1()
            let keuHash = sha1.hash(key, count: key.count).hexString
            self._cache[keuHash] = newValue
        }
    }
    
    public func saveCache() throws -> Document {
        try BSONEncoder().encode(_cache)
    }
    
    public func loadCache(from document: Document) throws {
        _cache = try BSONDecoder().decode([String: Credentials].self, from: document)
    }
}

/// This type contains all information needed to reduce the computational weight of authentication
struct Credentials: Codable {
    let saltedPassword: Data
    let clientKey: Data
    let serverKey: Data
}

/// A helper that can authenticate with the SCRAM machanism.
internal final class SCRAM<H: Hash> {
    var hasher: H
    var hmac: HMAC<H>

    private var state = ProgressState.none

    init(_ hasher: H) {
        self.hasher = hasher
        self.hmac = HMAC(hasher: hasher)
    }

    public func authenticationString(forUser user: String) throws -> String {
        guard case .none = self.state else {
            throw MongoAuthenticationError(reason: .internalError)
        }

        let nonce = String.randomNonce()

        self.state = .challenge(user: user, nonce: nonce)

        return "n,,n=\(user.normalized()),r=\(nonce)"
    }

    public func respond(toChallenge challengeString: String, password: String) throws -> String {
        guard case .challenge(let user, let nonce) = self.state else {
            throw MongoAuthenticationError(reason: .internalError)
        }

        let challenge = try decodeChallenge(challengeString)

        let noProof = "c=biws,r=\(challenge.nonce)"

        let saltedPassword: [UInt8]
        let clientKey: [UInt8]
        let serverKey: [UInt8]

        if let credentials = MongoCredentialsCache.default[password, challenge.iterations, challenge.salt] {
            saltedPassword = Array(credentials.saltedPassword)
            clientKey = Array(credentials.clientKey)
            serverKey = Array(credentials.serverKey)
        } else {
            // Check for sensible iterations, too
            guard
                let saltData = Data(base64Encoded: challenge.salt),
                challenge.iterations > 0 && challenge.iterations < 50_000,
                challenge.nonce.starts(with: nonce)
            else {
                throw MongoAuthenticationError(reason: .scramFailure)
            }

            let salt = Array(saltData)

            // TIDI: Cache login data
            saltedPassword = PBKDF2(digest: hasher).hash(
                Array(password.utf8),
                salt: salt,
                iterations: challenge.iterations
            )

            clientKey = hmac.authenticate(clientKeyBytes, withKey: saltedPassword)
            serverKey = hmac.authenticate(serverKeyBytes, withKey: saltedPassword)

            let credentials = Credentials(
                saltedPassword: Data(saltedPassword),
                clientKey: Data(clientKey),
                serverKey: Data(serverKey)
            )
            MongoCredentialsCache.default[password, challenge.iterations, challenge.salt] = credentials
        }

        let storedKey = hasher.hash(bytes: clientKey)

        let authenticationMessage = Array("n=\(user.normalized()),r=\(nonce),\(challengeString),\(noProof)".utf8)

        var clientSignature = hmac.authenticate(
            authenticationMessage,
            withKey: storedKey
        )
        _MongoKittenCrypto.xor(&clientSignature, clientKey, count: clientKey.count)

        let proof = Data(clientSignature).base64EncodedString()

        let serverSignature = hmac.authenticate(authenticationMessage, withKey: serverKey)

        self.state = .verify(signature: serverSignature)

        return "\(noProof),p=\(proof)"
    }

    public func completeAuthentication(withResponse response: String) throws {
        guard case .verify(let signature) = self.state else {
            throw MongoAuthenticationError(reason: .internalError)
        }

        defer {
            self.state = .none
        }

        guard response.count > 2 else {
            throw MongoAuthenticationError(reason: .scramFailure)
        }

        let index = response.index(response.startIndex, offsetBy: 2)
        guard response[response.startIndex ..< index] == "v=" else {
            throw MongoAuthenticationError(reason: .scramFailure)
        }

        let signatureString = String(response[index...])

        guard let signatureData = Data(base64Encoded: signatureString) else {
            throw MongoAuthenticationError(reason: .scramFailure)
        }

        guard signature == Array(signatureData) else {
            throw MongoAuthenticationError(reason: .scramFailure)
        }
    }

    private func decodeChallenge(_ challenge: String) throws -> Challenge {
        var nonce: String?
        var salt: String?
        var iterations: Int32?

        for parameter in challenge.split(separator: ",") where parameter.count >= 3 {
            let baseIndex = parameter.index(parameter.startIndex, offsetBy: 2)

            switch parameter.first {
            case "r"?:
                nonce = String(parameter[baseIndex...])
            case "s"?:
                salt = String(parameter[baseIndex...])
            case "i"?:
                let i = String(parameter[baseIndex...])
                iterations = Int32(i)
            default:
                throw MongoAuthenticationError(reason: .scramFailure)
            }
        }

        if
            let nonce = nonce,
            let salt = salt,
            let iterations = iterations
        {
            return Challenge(nonce: nonce, salt: salt, iterations: iterations)
        }

        throw MongoAuthenticationError(reason: .unexpectedSASLPhase)
    }
}

fileprivate struct Challenge {
    let nonce: String
    let salt: String
    let iterations: Int32
}

fileprivate let clientKeyBytes = Array("Client Key".utf8)
fileprivate let serverKeyBytes = Array("Server Key".utf8)

fileprivate extension String {
    mutating func saslPrepped(_ string: String) {
        /// FIXME: Reimplement SASLPrep according to spec
    }

    func normalized() -> String {
        return self
            .replacingOccurrences(of: "=", with: "=3D")
            .replacingOccurrences(of: ",", with: "=2C")
    }

    static func randomNonce() -> String {
        let allowedCharacters = "!\"#'$%&()*+-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_$"

        var randomString = ""

        let baseIndex = allowedCharacters.startIndex
        let maxCharacterIndex = allowedCharacters.count

        for _ in 0..<24 {
            let randomNumber: Int

            #if os(macOS) || os(iOS)
            randomNumber = Int(arc4random_uniform(UInt32(maxCharacterIndex)))
            #else
            randomNumber = Int(random() % maxCharacterIndex)
            #endif

            let letter = allowedCharacters[allowedCharacters.index(baseIndex, offsetBy: randomNumber)]

            randomString.append(letter)
        }

        return randomString
    }
}
