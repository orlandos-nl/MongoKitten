//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation
import CryptoSwift

/// Authenticates over SCRAM-SHA-1 to authenticate a user with the provided password
final class SCRAMClient {
    /// Constant GS2BindFlag
    let gs2BindFlag = "n,,"
    var server: Server
    
    /// Creates a new SCRAM Client instance
    init(_ server: Server) {
        self.server = server
    }
    
    /// Fixes the username to not contain variables that are essential to the SCRAM message structure
    ///
    /// - returns: The fixed username
    private func fixUsername(username user: String) -> String {
        return user.replacingOccurrences(of: "=", with: "=3D").replacingOccurrences(of: ",", with: "=2C")
    }
    
    /// Parses the SCRAM challenge and returns the values in there as a tuple
    ///
    /// - returns: The values in there as a tuple
    /// - throws: Unable to parse this message to a sever signature
    private func parse(challenge response: String) throws -> (nonce: String, salt: String, iterations: Int) {
        var nonce: String? = nil
        var iterations: Int? = nil
        var salt: String? = nil
        
        for part in response.characters.split(separator: ",") where String(part).characters.count >= 3 {
            let part = String(part)
            
            if let first = part.characters.first {
                let data = part[part.index(part.startIndex, offsetBy: 2)..<part.endIndex]
                
                switch first {
                case "r":
                    nonce = data
                case "i":
                    iterations = Int(data)
                case "s":
                    salt = data
                default:
                    break
                }
            }
        }
        
        if let nonce = nonce, let iterations = iterations, let salt = salt {
            return (nonce: nonce, salt: salt, iterations: iterations)
        }
        
        throw AuthenticationError.challengeParseError(challenge: response)
    }
    
    /// Parses the final response and returns the server signature
    ///
    /// - returns: The server signature
    /// - throws: Unable to parse this message to a sever signature
    private func parse(finalResponse response: String) throws -> Bytes {
        var signature: Bytes? = nil
        
        for part in response.characters.split(separator: ",") where String(part).characters.count >= 3 {
            let part = String(part)
            
            if let first = part.characters.first {
                let data = part[part.index(part.startIndex, offsetBy: 2)..<part.endIndex]
                
                switch first {
                case "v":
                    signature = Array(try Base64.decode(data))
                default:
                    break
                }
            }
        }
        
        if let signature = signature {
            return signature
        }
        
        throw AuthenticationError.responseParseError(response: response)
    }
    
    /// Generates an initial SCRAM-SHA-1 authentication String
    func authenticate(_ username: String, usingNonce nonce: String) throws -> String {
        return "\(gs2BindFlag)n=\(fixUsername(username: username)),r=\(nonce)"
    }
    
    /// Processes the challenge and responds with the proof that we are the user we claim to be
    ///
    /// - returns: A tuple where the proof is to be sent to the server and the signature is to be verified in the server's responses.
    /// - throws: When unable to parse the challenge
    func process(_ challenge: String, with details: (username: String, password: Bytes), usingNonce nonce: String) throws -> (proof: String, serverSignature: Bytes) {
        func xor(_ lhs: Bytes, _ rhs: Bytes) -> Data {
            var result = Data(repeating: 0, count: min(lhs.count, rhs.count))
            
            for i in 0..<result.count {
                result[i] = lhs[i] ^ rhs[i]
            }
            
            return result
        }
        
        let encodedHeader = Base64.encode(Data(bytes: Bytes(gs2BindFlag.utf8)))
        
        let parsedResponse = try parse(challenge: challenge)

        let remoteNonce = parsedResponse.nonce
        
        guard String(remoteNonce[remoteNonce.startIndex..<remoteNonce.index(remoteNonce.startIndex, offsetBy: 24)]) == nonce else {
            throw AuthenticationError.invalidNonce(nonce: parsedResponse.nonce)
        }
        
        let noProof = "c=\(encodedHeader),r=\(parsedResponse.nonce)"
        
        let data = try Base64.decode(parsedResponse.salt)
        
        let salt = Array(data)
        let saltedPassword: Bytes
        
        if let hashedPassword = server.hashedPassword {
            saltedPassword = hashedPassword
        } else {
            saltedPassword = try PKCS5.PBKDF2(password: details.password, salt: salt, iterations: parsedResponse.iterations, variant: .sha1).calculate()
            server.hashedPassword = saltedPassword
        }
        
        let ck = Bytes("Client Key".utf8)
        let sk = Bytes("Server Key".utf8)
        
        let clientKey = try HMAC(key: saltedPassword, variant: .sha1).authenticate(ck)
        let serverKey = try HMAC(key: saltedPassword, variant: .sha1).authenticate(sk)

        let storedKey = Digest.sha1(clientKey)

        let authenticationMessage = "n=\(fixUsername(username: details.username)),r=\(nonce),\(challenge),\(noProof)"

        var authenticationMessageBytes = Bytes()
        authenticationMessageBytes.append(contentsOf: authenticationMessage.utf8)
        
        let clientSignature = try HMAC(key: storedKey, variant: .sha1).authenticate(authenticationMessageBytes)
        let clientProof = xor(clientKey, clientSignature)
        let serverSignature = try HMAC(key: serverKey, variant: .sha1).authenticate(authenticationMessageBytes)
        
        let proof = Base64.encode(clientProof)

        return (proof: "\(noProof),p=\(proof)", serverSignature: serverSignature)
    }
    
    /// Validates the server's signature
    ///
    /// - returns: An empty string to proceed the process indefinitely until complete as per protocol definition
    /// - throws: When the server's signature is invalid
    func complete(fromResponse response: String, verifying signature: Bytes) throws -> String {
        let sig = try parse(finalResponse: response)

        if sig != signature {
            throw AuthenticationError.serverSignatureInvalid
        }
        
        return ""
    }
}
