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
import Socket
import SSLService

final class Connection {
    
    let logger: FrameworkLogger

    var used = false
    var writable = false
    var authenticatedDBs: [String] = []
    var onClose: (()->())

    let host: MongoHost
    
    private let socket: Socket

    
    
    /// A cache for incoming responses
    var incomingMutateLock = NSLock()
    
    public var isConnected: Bool {
        return socket.isConnected
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
       
        self.socket = try Socket.create() // tcp socket

        
        if let sslSettings = clientSettings.sslSettings, sslSettings.enabled {
            
            var sslConfig = SSLService.Configuration(withCipherSuite: nil)
            #if os(Linux)
                if let sslCAFile = options["sslCAFile"] as? String {
             
                        if let cert = try? String(contentsOfFile: sslCAFile,encoding: .utf8) {
                            let trimmedCert = cert.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            sslConfig = SSLService.Configuration(withPEMCertificateString: trimmedCert)
                        }
                   
                }
            #endif
            self.socket.delegate = try SSLService(usingConfiguration: sslConfig)
        }
        
        try socket.connect(to: host.hostname, port: Int32(host.port))
        
        
        
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
        socket.close()
        onClose()
    }
    
    func send(data binary: [UInt8]) throws -> (Int32,Message)? {
        
        try socket.write(from: UnsafeRawPointer(binary), bufSize: binary.count)
        var readData = Data(capacity: self.socket.readBufferSize)

        var shouldKeepRunning = true
        var reply: Message?
        var responseId: Int32?
        var buffer = [UInt8]()
        repeat {
            let _ = try socket.read(into: &readData)
            buffer += readData.bytes
            readData.removeAll()

            if buffer.count >= 36 {
                
                let length = Int(buffer[0...3].makeInt32())
                if length <= buffer.count {
                    let responseData = buffer[0..<length]*
                    responseId = buffer[8...11].makeInt32()
                    reply = try Message.makeReply(from: responseData)
                    
//                    if let closure = waitingForResponses[responseId] {
//                        closure(reply)
//                        waitingForResponses[responseId] = nil
//                    }
                    shouldKeepRunning = false
                }
                
            }
        } while shouldKeepRunning

        if let responseId = responseId, let reply = reply {
            return (responseId,reply)
        } else {
            return nil
        }
    }
}
