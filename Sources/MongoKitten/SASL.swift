#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Foundation
import _MongoKittenCrypto

fileprivate enum ProgressState {
    case none
    case challenge(user: String, nonce: String)
    case verify(signature: [UInt8])
}

// TODO: Cache scram credentials between multiple connections/threads
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
            throw MongoKittenError(.authenticationFailure, reason: .internalError)
        }
        
        let nonce = String.randomNonce()
        
        self.state = .challenge(user: user, nonce: nonce)
        
        return "\(gs2BindFlag)n=\(user.normalized()),r=\(nonce)"
    }
    
    public func respond(toChallenge challengeString: String, password: String) throws -> String {
        guard case .challenge(let user, let nonce) = self.state else {
            throw MongoKittenError(.authenticationFailure, reason: .internalError)
        }
        
        let challenge = try decodeChallenge(challengeString)
        
        let noProof = "c=\(encodedGs2BindFlag),r=\(challenge.nonce)"
        
        // TODO: Custom simple base64 decoder
        
        // Check for sensible iterations, too
        guard
            let saltData = Data(base64Encoded: challenge.salt),
            challenge.iterations > 0 && challenge.iterations < 50_000
        else {
            throw MongoKittenError(.authenticationFailure, reason: .scramFailure)
        }
        
        let salt = Array(saltData)
        
        // TIDI: Cache login data
        let saltedPassword = PBKDF2(digest: hasher).hash(
            Array(password.utf8),
            salt: salt,
            iterations: challenge.iterations
        )
        
        let clientKey = hmac.authenticate(clientKeyBytes, withKey: saltedPassword)
        let serverKey = hmac.authenticate(serverKeyBytes, withKey: saltedPassword)
        
        let storedKey = hasher.hash(bytes: clientKey)
        
        let authenticationMessage = Array("n=\(user.normalized()),r=\(nonce),\(challengeString),\(noProof)".utf8)
        
        var clientSignature = hmac.authenticate(
            authenticationMessage,
            withKey: storedKey
        )
        xor(&clientSignature, clientKey)
        
        let proof = Data(bytes: clientSignature).base64EncodedString()
        
        let serverSignature = hmac.authenticate(authenticationMessage, withKey: serverKey)
        
        self.state = .verify(signature: serverSignature)
        
        return "\(noProof),p=\(proof)"
    }
    
    public func completeAuthentication(withResponse response: String) throws {
        guard case .verify(let signature) = self.state else {
            throw MongoKittenError(.authenticationFailure, reason: .internalError)
        }
        
        guard response.count > 2 else {
            throw MongoKittenError(.authenticationFailure, reason: .scramFailure)
        }
        
        let index = response.index(response.startIndex, offsetBy: 2)
        
        let signatureString = String(response[index...])
        
        guard let signatureData = Data(base64Encoded: signatureString) else {
            throw MongoKittenError(.authenticationFailure, reason: .scramFailure)
        }
        
        guard signature == Array(signatureData) else {
            throw MongoKittenError(.authenticationFailure, reason: .scramFailure)
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
                throw MongoKittenError(.authenticationFailure, reason: .scramFailure)
            }
        }
        
        if
            let nonce = nonce,
            let salt = salt,
            let iterations = iterations
        {
            return Challenge(nonce: nonce, salt: salt, iterations: iterations)
        }
        
        throw MongoKittenError(.authenticationFailure, reason: .unexpectedValue)
    }
}

fileprivate struct Challenge {
    let nonce: String
    let salt: String
    let iterations: Int32
}

fileprivate let gs2BindFlag = "n,,"
fileprivate let encodedGs2BindFlag = "biws"
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
