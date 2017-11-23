import Foundation
import Async
import BSON
import Crypto

extension DatabaseConnection {
    /// Parses a SCRAM response
    ///
    /// - parameter response: The SCRAM response to parse
    ///
    /// - returns: The Dictionary that's build from the response
    fileprivate func parse(response r: String) -> [String: String] {
        var parsedResponse = [String: String]()
        
        for part in r.characters.split(separator: ",") where String(part).characters.count >= 3 {
            let part = String(part)
            
            if let first = part.characters.first {
                parsedResponse[String(first)] = String(part[part.index(part.startIndex, offsetBy: 2)..<part.endIndex])
            }
        }
        
        return parsedResponse
    }
}

struct Complete: Codable {
    var ok: Double
    var done: Bool?
    var payload: String
    var conversationId: Int
}

extension DatabaseConnection {
    /// Processes the last step(s) in the SASL process
    ///
    /// - parameter payload: The previous payload
    /// - parameter response: The response we got from the server
    /// - parameter signature: The server signatue to verify
    ///
    /// - throws: On authentication failure or an incorrect Server Signature
    private func complete(response: Document, verifying signature: Data, database: String) throws -> Future<Void> {
        let response = try BSONDecoder.decodeOrError(Complete.self, from: response)
        
        if response.ok > 0 && response.done == true {
            return Future(())
        }
        
        let finalResponseData = try Base64Decoder.decode(string: response.payload)
        
        guard let finalResponse = String(data: finalResponseData, encoding: .utf8) else {
            throw MongoError.invalidBase64String
        }
        
        let dictionaryResponse = self.parse(response: finalResponse)
        
        guard let v = dictionaryResponse["v"] else {
            throw AuthenticationError.responseParseError(response: response.payload)
        }
        
        let serverSignature = try Base64Decoder.decode(string: v)
        
        guard serverSignature == signature else {
            throw AuthenticationError.serverSignatureInvalid
        }
        
        let commandMessage = Message.Query(
            requestID: self.nextRequestId,
            flags: [],
            collection: database + ".$cmd",
            numbersToSkip: 0,
            numbersToReturn: 1,
            query: [
                "saslContinue": Int32(1),
                "conversationId": response.conversationId,
                "payload": ""
            ],
            returnFields: nil
        )
        
        return send(message: commandMessage).flatMap { reply in
            return try self.complete(response: reply.documents.first ?? [:], verifying: signature, database: database)
        }
    }
    
    /// Respond to a challenge
    ///
    /// - parameter details: The authentication details
    /// - parameter previousInformation: The nonce, response and `SCRAMClient` instance
    ///
    /// - throws: When the authentication fails, when Base64 fails
    private func challenge(credentials: MongoCredentials, nonce: String, response: Document) throws -> Future<Void> {
        let response = try BSONDecoder.decodeOrError(Complete.self, from: response)
        
        // If we failed the authentication
        guard response.ok == 1 else {
            throw AuthenticationError.incorrectCredentials
        }
        
        let stringResponseData = try Base64Decoder.decode(string: response.payload)
        
        guard let decodedStringResponse = String(data: stringResponseData, encoding: .utf8) else {
            throw MongoError.invalidBase64String
        }
        
        let digestBytes = Data("\(credentials.username):mongo:\(credentials.password)".utf8)
        let passwordBytes = Data(MD5.hash(digestBytes).hexString.utf8)
        
        let result = try self.scram.process(decodedStringResponse, username: credentials.username, password: passwordBytes, usingNonce: nonce)
        
        // Base64 the payload
        let payload = Base64Encoder.encode(string: result.proof)
        
        // Send the proof
        let commandMessage = Message.Query(
            requestID: self.nextRequestId,
            flags: [],
            collection: credentials.authDB + ".$cmd",
            numbersToSkip: 0,
            numbersToReturn: 1,
            query: [
                "saslContinue": Int32(1),
                "conversationId": response.conversationId,
                "payload": payload
            ],
            returnFields: nil
        )
        
        return send(message: commandMessage).flatMap { reply in
            return try self.complete(response: reply.documents.first ?? [:], verifying: result.serverSignature, database: credentials.authDB)
        }
    }
    
    /// Authenticates to this database using SASL
    ///
    /// - parameter details: The authentication details
    ///
    /// - throws: When failing authentication, being unable to base64 encode or failing to send/receive messages
    internal func authenticateSASL(_ credentials: MongoCredentials) throws -> Future<Void> {
        let nonce = randomNonce()
        
        let authPayload = scram.authenticate(credentials.username, usingNonce: nonce)
        
        let payload = Base64Encoder.encode(string: authPayload)
        
        let message = Message.Query(
            requestID: self.nextRequestId,
            flags: [],
            collection: credentials.authDB + ".$cmd",
            numbersToSkip: 0,
            numbersToReturn: 1,
            query: [
                "saslStart": Int32(1),
                "mechanism": "SCRAM-SHA-1",
                "payload": payload
            ],
            returnFields: nil
        )
        
        return send(message: message).flatMap { reply in
            return try self.challenge(credentials: credentials, nonce: nonce, response: reply.documents.first ?? [:])
        }
    }
}
