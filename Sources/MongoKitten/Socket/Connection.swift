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
import LogKitten
import Dispatch
import MongoSocket

class Connection {
    
    let logger: FrameworkLogger
    private let client: MongoTCP
    let buffer = TCPBuffer()
    var used = false
    var writable = false
    var authenticatedDBs: [String] = []
    var onClose: (()->())
    let host: MongoHost
    var incomingBuffer = [UInt8]()

    private static let receiveQueue = DispatchQueue(label: "org.mongokitten.server.receiveQueue", attributes: .concurrent)
    
    var waitingForResponses = [Int32:(Message)->()]()
    
    /// A cache for incoming responses
    var incomingMutateLock = NSLock()
    
    public var isConnected: Bool {
        return client.isConnected
    }
    
    init(clientSettings: ClientSettings, writable: Bool, host: MongoHost, logger: FrameworkLogger, onClose: @escaping (()->())) throws {

        var options = [String:Any] ()
        if let sslSettings = clientSettings.sslSettings {
            options["sslEnabled"]  = sslSettings.enabled
            options["invalidCertificateAllowed"]  = sslSettings.invalidCertificateAllowed
            options["invalidHostNameAllowed"] = sslSettings.invalidHostNameAllowed
            if let sslCAFile = sslSettings.sslCAFile {
                options["sslCAFile"] = sslCAFile
            }
        } else {
            options["sslEnabled"]  = false
        }

        self.client = try MongoSocket(address: host.hostname, port: host.port, options: options)
        self.writable = writable
        self.onClose = onClose
        self.host = host
        self.logger = logger
        
    }
    
    func authenticate(toDatabase db: Database) throws {
        if let details = db.server.clientSettings.credentials {
            do {
                switch details.authenticationMechanism {
                case .SCRAM_SHA_1:
                    try db.authenticate(SASL: details, usingConnection: self)
                case .MONGODB_CR:
                    try db.authenticate(mongoCR: details, usingConnection: self)
                default:
                    throw MongoError.unsupportedFeature("authentication Method")
                }
                
                self.authenticatedDBs.append(db.name)
            } catch { }
        }
    }
    
    
    
    func close() {
        _ = try? client.close()
        onClose()
    }
    
    func send(data binary: [UInt8]) throws {
        try self.client.send(data: binary)
        try self.receive()
    }

    
    /// Called by the server thread to handle MongoDB Wire messages
    ///
    /// - parameter bufferSize: The amount of bytes to fetch at a time
    ///
    /// - throws: Unable to receive or parse the reply
    private func receive() throws {
        var incommingData = Data()
        try client.receive(into: &incommingData)
        buffer.data += incommingData.bytes
        
        while buffer.data.count >= 36 {
            let length = Int(buffer.data[0...3].makeInt32())
            
            guard length <= buffer.data.count else {
                try receive()
                return
            }
            
            let responseData = buffer.data[0..<length]*
            let responseId = buffer.data[8...11].makeInt32()
            let reply = try Message.makeReply(from: responseData)
            
            if let closure = waitingForResponses[responseId] {
                closure(reply)
                waitingForResponses[responseId] = nil
            } else {
                
            }
            
            buffer.data.removeSubrange(0..<length)
        }
    }
}
