//
//  NewDatabase.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 24/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON
//import Venice

public enum MongoError : ErrorType {
    case MongoDatabaseUnableToConnect, MongoDatabaseAlreadyConnected, InvalidBodyLength, InvalidAction, MongoDatabaseNotYetConnected, InsertFailure(documents: [Document]), QueryFailure(query: Document), UpdateFailure(from: Document, to: Document), RemoveFailure(query: Document), HandlerNotFound
}

internal typealias ResponseHandler = ((reply: ReplyMessage) -> Void)

public class Server : NSObject, NSStreamDelegate {
    //internal var mongoSocket: TCPClientSocket?
    internal var outputStream: NSOutputStream?
    internal var inputStream: NSInputStream?
    private var connected = false
    private var inputOpen = false
    private var outputOpen = false
    private let host: String
    private let port: Int
    internal var lastRequestID: Int32 = -1
    internal var databases = [String:Database]()
    internal var responseHandlers = [Int32:(ResponseHandler, Message)]()
    internal var fullBuffer = [UInt8]()
    
    public init(host: String, port: Int, autoConnect: Bool = false) throws {
        self.host = host
        self.port = port
        super.init()
        
        if autoConnect {
            try self.connect()
        }
    }
    
    public subscript (database: String) -> Database {
        let database = database.stringByReplacingOccurrencesOfString(".", withString: "")
        
        if let database: Database = databases[database] {
            return database
        }
        
        let databaseObject = Database(server: self, databaseName: database)
        
        databases[database] = databaseObject
        
        return databaseObject
    }
    
    internal func getNextMessageID() -> Int32 {
        lastRequestID += 1
        return lastRequestID
    }
    
    public func connect() throws {
        guard outputStream == nil && inputStream == nil else {
            throw MongoError.MongoDatabaseAlreadyConnected
        }
        
        if connected {
            throw MongoError.MongoDatabaseAlreadyConnected
        }
        
        NSStream.getStreamsToHostWithName(self.host, port: self.port, inputStream: &inputStream, outputStream: &outputStream)
        
        inputStream!.delegate = self
        outputStream!.delegate = self
        
        inputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)

        inputStream!.open()
        outputStream!.open()
        
        connected = true
    }
    
    public func disconnect() throws {
        guard connected && outputStream != nil && inputStream != nil else {
            throw MongoError.MongoDatabaseNotYetConnected
        }
        
        inputStream?.close()
        outputStream?.close()
        
        connected = false
    }
    
    @objc public func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
        if stream === inputStream {
            switch eventCode {
            case NSStreamEvent.ErrorOccurred:
                print("InputStream error occured")
            case NSStreamEvent.OpenCompleted:
                inputOpen = true
            case NSStreamEvent.HasBytesAvailable:
                var buffer = [UInt8]()
                var readBytes: Int
                
                repeat {
                    var tempBuffer = [UInt8](count: 256, repeatedValue: 0)
                    
                    readBytes = inputStream!.read(&tempBuffer, maxLength: tempBuffer.capacity)
                    buffer.appendContentsOf(tempBuffer[0..<readBytes])
                    
                } while(readBytes > 0 && readBytes == 256)
                
                fullBuffer += buffer
                
                do {
                    while fullBuffer.count >= 36 {
                        guard let length: Int = Int(try Int32.instantiate(bsonData: fullBuffer[0...3]*)) else {
                            throw DeserializationError.ParseError
                        }
                        
                        guard length <= fullBuffer.count else {
                            throw MongoError.InvalidBodyLength
                        }
                        
                        let responseData = fullBuffer[0..<length]*
                        let responseId = try Int32.instantiate(bsonData: fullBuffer[8...11]*)
                        
                        if let handler: (ResponseHandler, Message) = responseHandlers[responseId] {
                            let response = try ReplyMessage.init(collection: handler.1.collection, data: responseData)
                            handler.0(reply: response)
                            responseHandlers.removeValueForKey(handler.1.requestID)
                            
                            fullBuffer.removeRange(0..<length)
                        } else {
                            throw MongoError.HandlerNotFound
                        }
                    }
                } catch _ { }
                break
            default:
                break
            }
            
        } else if stream == outputStream {
            switch eventCode {
            case NSStreamEvent.ErrorOccurred:
                print("OutputStream error occured")
            case NSStreamEvent.OpenCompleted:
                outputOpen = true
            case NSStreamEvent.HasSpaceAvailable:
                break
            default:
                break
            }
        }
    }
    
    /**
     Send given message to the server.
     
     - parameter message: A message to send to the server
     - parameter handler: The handler will be executed when a response is received. Note the server does not respond to every message.
     
     - returns: `true` if the message was sent sucessfully
     */
    internal func sendMessage(message: Message, handler: ResponseHandler? = nil) throws -> Bool {
        if !connected || outputStream == nil {
            throw MongoError.MongoDatabaseUnableToConnect
        }
        
        let messageData = try message.generateBsonMessage()
        
        if let handler: ResponseHandler = handler {
            responseHandlers[message.requestID] = (handler, message)
        }
        
        guard let output: Int = outputStream?.write(messageData, maxLength: messageData.count) else {
            return false
        }
        
        return output >= 0
    }
}