//
//  Connection.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 22/12/2016.
//
//

import Foundation
import LogKitten
import Dispatch

class Connection {
    
    let logger: FrameworkLogger
    let client: MongoTCP
    let buffer = TCPBuffer()
    var used = false
    var writable = false
    var authenticatedDBs: [String] = []
    var onClose: (()->())
    let host: MongoHost
    
    private static let receiveQueue = DispatchQueue(label: "org.mongokitten.server.receiveQueue", attributes: .concurrent)
    
    var waitingForResponses = [Int32:(Message)->()]()
    
    /// A cache for incoming responses
    var incomingMutateLock = NSLock()
    
    public var isConnected: Bool {
        return client.isConnected
    }
    
    init(client: MongoTCP, writable: Bool, host: MongoHost, logger: FrameworkLogger, onClose: @escaping (()->())) {
        self.client = client
        self.writable = writable
        self.onClose = onClose
        self.host = host
        self.logger = logger
        
        Connection.receiveQueue.async(execute: backgroundLoop)
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
    
    
    /// Receives response messages from the server and gives them to the callback closure
    /// After handling the response with the closure it removes the closure
    fileprivate func backgroundLoop() {
        do {
            try self.receive()
        } catch {
            // A receive failure is to be expected if the socket has been closed
            incomingMutateLock.lock()
            if self.isConnected {
                logger.fatal("The MongoKitten background loop encountered an error and has stopped: \(error)")
                logger.fatal("Please file a report on https://github.com/openkitten/mongokitten")
            }
            incomingMutateLock.unlock()
            
            return
        }
        
        Connection.receiveQueue.async(execute: backgroundLoop)
    }
    
    func close() {
        _ = try? client.close()
        onClose()
    }
    
    /// Called by the server thread to handle MongoDB Wire messages
    ///
    /// - parameter bufferSize: The amount of bytes to fetch at a time
    ///
    /// - throws: Unable to receive or parse the reply
    private func receive(bufferSize: Int = 1024) throws {
        // TODO: Respect bufferSize
        let incomingBuffer: [UInt8] = try client.receive()
        buffer.data += incomingBuffer
        
        while buffer.data.count >= 36 {
            let length = Int(buffer.data[0...3].makeInt32())
            
            guard length <= buffer.data.count else {
                // Ignore: Wait for more data
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
