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
///
/// TODO: Make this internal
final class SCRAMClient {
    /// Constant GS2BindFlag
    let gs2BindFlag = "n,,"
    var server: Server
    
    /// Creates a new SCRAM Client instance
    ///
    /// TODO: Make this internal
    init(_ server: Server) {
        self.server = server
    }
    
    /// Fixes the username to not contain variables that are essential to the SCRAM message structure
    ///
    /// - returns: The fixed username
    private func fixUsername(username user: String) -> String {
        return replaceOccurrences(in: replaceOccurrences(in: user, where: "=", with: "=3D"), where: ",", with: "=2C")
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
        
        throw SCRAMError.ChallengeParseError(challenge: response)
    }
    
    /// Parses the final response and returns the server signature
    ///
    /// - returns: The server signature
    /// - throws: Unable to parse this message to a sever signature
    private func parse(finalResponse response: String) throws -> [UInt8] {
        var signature: [UInt8]? = nil
        
        for part in response.characters.split(separator: ",") where String(part).characters.count >= 3 {
            let part = String(part)
            
            if let first = part.characters.first {
                let data = part[part.index(part.startIndex, offsetBy: 2)..<part.endIndex]
                
                switch first {
                case "v":
                    guard let signatureData = Data(base64Encoded: data) else {
                        throw MongoError.invalidBase64String
                    }
                    signature = Array(signatureData)
                default:
                    break
                }
            }
        }
        
        if let signature = signature {
            return signature
        }
        
        throw SCRAMError.ResponseParseError(response: response)
    }
    
    /// Generates an initial SCRAM-SHA-1 authentication String
    ///
    /// TODO: Make this internal
    func authenticate(_ username: String, usingNonce nonce: String) throws -> String {
        return "\(gs2BindFlag)n=\(fixUsername(username: username)),r=\(nonce)"
    }
    
    /// Processes the challenge and responds with the proof that we are the user we claim to be
    ///
    /// TODO: Make this internal
    ///
    /// - returns: A tuple where the proof is to be sent to the server and the signature is to be verified in the server's responses.
    /// - throws: When unable to parse the challenge
    func process(_ challenge: String, with details: (username: String, password: [UInt8]), usingNonce nonce: String) throws -> (proof: String, serverSignature: [UInt8]) {
        func xor(_ lhs: [UInt8], _ rhs: [UInt8]) -> [UInt8] {
            var result = [UInt8](repeating: 0, count: min(lhs.count, rhs.count))
            
            for i in 0..<result.count {
                result[i] = lhs[i] ^ rhs[i]
            }
            
            return result
        }
        
        let encodedHeader = Data(bytes: [UInt8](gs2BindFlag.utf8)).base64EncodedString()
        
        let parsedResponse = try parse(challenge: challenge)

        let remoteNonce = parsedResponse.nonce
        
        guard String(remoteNonce[remoteNonce.startIndex..<remoteNonce.index(remoteNonce.startIndex, offsetBy: 24)]) == nonce else {
            throw SCRAMError.InvalidNonce(nonce: parsedResponse.nonce)
        }
        
        let noProof = "c=\(encodedHeader),r=\(parsedResponse.nonce)"
        
        guard let data = Data(base64Encoded: parsedResponse.salt) else {
            throw MongoError.invalidBase64String
        }
        
        let salt = Array(data)
        let saltedPassword: [UInt8]
        
        if let hashedPassword = server.hashedPassword {
            saltedPassword = hashedPassword
        } else {
            saltedPassword = try PKCS5.PBKDF2(password: details.password, salt: salt, iterations: parsedResponse.iterations, variant: .sha1).calculate()
            server.hashedPassword = saltedPassword
        }
        
        let ck = [UInt8]("Client Key".utf8)
        let sk = [UInt8]("Server Key".utf8)
        
        let clientKey = try HMAC(key: saltedPassword, variant: .sha1).authenticate(ck)
        let serverKey = try HMAC(key: saltedPassword, variant: .sha1).authenticate(sk)

        let storedKey = Digest.sha1(clientKey)

        let authenticationMessage = "n=\(fixUsername(username: details.username)),r=\(nonce),\(challenge),\(noProof)"

        var authenticationMessageBytes = [UInt8]()
        authenticationMessageBytes.append(contentsOf: authenticationMessage.utf8)
        
        let clientSignature = try HMAC(key: storedKey, variant: .sha1).authenticate(authenticationMessageBytes)
        let clientProof = xor(clientKey, clientSignature)
        let serverSignature = try HMAC(key: serverKey, variant: .sha1).authenticate(authenticationMessageBytes)
        
        let proof = Data(bytes: clientProof).base64EncodedString()

        return (proof: "\(noProof),p=\(proof)", serverSignature: serverSignature)
    }
    
    /// Validates the server's signature
    ///
    /// TODO: Make this internal
    ///
    /// - returns: An empty string to proceed the process indefinitely until complete as per protocol definition
    /// - throws: When the server's signature is invalid
    func complete(fromResponse response: String, verifying signature: [UInt8]) throws -> String {
        let sig = try parse(finalResponse: response)

        if sig != signature {
            throw SCRAMError.InvalidSignature(signature: sig)
        }
        
        return ""
    }
}

/// Replaces occurrences of data with new data in a string
/// Because "having a single cross-platform API for a programming language is stupid"
/// TODO: Remove/update with the next Swift version
internal func replaceOccurrences(`in` string: String, `where` matching: String, with replacement: String) -> String {
    return string.replacingOccurrences(of: matching, with: replacement)
}

/// All possible authentication errors
public enum SCRAMError: Error {
    /// -
    case InvalidSignature(signature: [UInt8])
    
    /// -
    case Base64Failure(original: [UInt8])
    
    /// -
    case ChallengeParseError(challenge: String)
    
    /// -
    case ResponseParseError(response: String)
    
    /// -
    case InvalidNonce(nonce: String)
}
