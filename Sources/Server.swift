//
//  NewDatabase.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 24/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON
import When


public enum MongoError : ErrorType {
    case MongoDatabaseUnableToConnect
    case MongoDatabaseAlreadyConnected
    case InvalidBodyLength
    case InvalidAction
    case MongoDatabaseNotYetConnected
    case InsertFailure(documents: [Document])
    case QueryFailure(query: Document)
    case UpdateFailure(from: Document, to: Document)
    case RemoveFailure(query: Document)
    case HandlerNotFound
}

/// A ResponseHandler is a closure that receives a MongoReply to process it
/// It's internal because ReplyMessages are an internal struct that is used for direct communication with MongoDB only
internal typealias ResponseHandler = ((reply: ReplyMessage) -> Void)

/// A server object is the core of MongoKitten. From this you can get databases which can provide you with collections from where you can do actions
public class Server : NSObject, NSStreamDelegate {
    /// Is the socket connected?
    private var connected = false
    
    /// Is input open
    private var inputOpen = false
    
    /// Is output open
    private var outputOpen = false
    
    /// The MongoDB-server's hostname
    private let host: String
    
    /// The MongoDB-server's port
    private let port: Int
    
    /// The last Request we sent.. -1 if no request was sent
    internal var lastRequestID: Int32 = -1
    
    /// A dictionary that keeps track of all Find-request's IDs and their responseHandlers
    internal var responseHandlers = [Int32:(ResponseHandler, Message)]()
    
    /// The full buffer of received bytes from MongoDB
    internal var fullBuffer = [UInt8]()
    
    /// Initializes a server with a given host and port. Optionally automatically connects
    /// - parameter host: The host we'll connect with for the MongoDB Server
    /// - parameter port: The port we'll connect on with the MongoDB Server
    /// - parameter autoConnect: Whether we automatically connect
    public init(host: String, port: Int = 27017, autoConnect: Bool = false) throws {
        self.host = host
        self.port = port
        super.init()
        
        if autoConnect {
            try !>self.connect()
        }
    }
    
    /// This subscript returns a Database struct given a String
    public subscript (database: String) -> Database {
        let database = database.stringByReplacingOccurrencesOfString(".", withString: "")
        
        return Database(server: self, databaseName: database)
    }
    
    /// Generates a messageID for the next Message
    internal func getNextMessageID() -> Int32 {
        lastRequestID += 1
        return lastRequestID
    }
    
    /// Connects with the MongoDB Server using the given information in the initializer
    public func connect() -> ThrowingFuture<Void> {
        return ThrowingFuture {
            guard self.outputStream == nil && self.inputStream == nil else {
                throw MongoError.MongoDatabaseAlreadyConnected
            }
            
            if self.connected {
                throw MongoError.MongoDatabaseAlreadyConnected
            }
            
            NSStream.getStreamsToHostWithName(self.host, port: self.port, inputStream: &self.inputStream, outputStream: &self.outputStream)
            
            self.inputStream!.delegate = self
            self.outputStream!.delegate = self
            
            self.socketThread.start()
            
            self.inputStream!.open()
            self.outputStream!.open()
            
            self.connected = true
        }
    }
    
    /// Disconnects from the MongoDB server
    public func disconnect() throws {
        guard let inputStream = inputStream, outputStream = outputStream where connected else {
            throw MongoError.MongoDatabaseNotYetConnected
        }
        
        inputStream.close()
        outputStream.close()
        
        connected = false
    }
    
    @objc public func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
        if stream == inputStream {
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
        guard let outputStream = outputStream where connected else {
            throw MongoError.MongoDatabaseUnableToConnect
        }
        
        let messageData = try message.generateBsonMessage()
        
        if let handler = handler {
            responseHandlers[message.requestID] = (handler, message)
        }
        
        guard let output: Int = outputStream.write(messageData, maxLength: messageData.count) else {
            return false
        }
        
        return output >= 0
    }
}