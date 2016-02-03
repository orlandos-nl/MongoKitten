//
//  NewDatabase.swift
//  MongoSwift
//
//  Created by Joannis Orlandos on 24/01/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import BSON

public enum MongoError : ErrorType {
    case MongoDatabaseUnableToConnect, MongoDatabaseAlreadyConnected, InvalidBodyLength, InvalidDatabaseName, InvalidFullCollectionName, InvalidCollectionName, MongoDatabaseNotYetConnected, BrokenCollectionObject, BrokenDatabaseObject, InvalidAction
}

public typealias ResponseHandler = ((reply: ResponseMessage) -> Void)

public class Server : NSObject, NSStreamDelegate {
    internal var inputStream: NSInputStream?
    internal var outputStream: NSOutputStream?
    private var connected = false
    private var inputOpen = false
    private var outputOpen = false
    private let host: String
    private let port: Int
    internal var lastRequestID: Int32 = -1
    internal var databases = [String:Database]()
    internal var responseHandlers = [Int32:(ResponseHandler, Message)]()
    
    public init(host: String, port: Int, autoConnect: Bool = false) throws {
        self.host = host
        self.port = port
        
        super.init()
        
        if autoConnect {
            try self.connect()
        }
    }
    
    public subscript (database: String) -> Database {
        if let database: Database = databases[database] {
            return database
        }
        
        let database = database.stringByReplacingOccurrencesOfString(".", withString: "")
        
        if database.isEmpty {
            print("Trying to access empty collection")
            abort()
        }
        
        let databaseObject = try! Database(server: self, databaseName: database)
        
        databases[database] = databaseObject
        
        return databaseObject
    }
    
    func getNextMessageID() -> Int32 {
        lastRequestID += 1
        return lastRequestID
    }
    
    public func connect() throws {
        NSStream.getStreamsToHostWithName(host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        
        guard inputStream != nil && outputStream != nil else {
            throw MongoError.MongoDatabaseUnableToConnect
        }
        
        if connected {
            throw MongoError.MongoDatabaseAlreadyConnected
        }
        
        inputStream!.delegate = self
        outputStream!.delegate = self
        
        inputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        
        inputStream!.open()
        outputStream!.open()
        
        connected = true
    }
    
    public func disconnect() throws {
        guard connected && inputStream != nil && outputStream != nil else {
            throw MongoError.MongoDatabaseNotYetConnected
        }
        
        connected = false
        
        inputStream!.close()
        outputStream!.close()
        
        inputStream = nil
        outputStream = nil
    }
    
    @objc public func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
        if stream === inputStream {
            switch eventCode {
            case NSStreamEvent.ErrorOccurred:
                print("InputStream error occured")
            case NSStreamEvent.OpenCompleted:
                inputOpen = true
            case NSStreamEvent.HasBytesAvailable:
                var fullBuffer = [UInt8]()
                var buffer = [UInt8](count: 256, repeatedValue: 0)
                var readBytes: Int
                
                repeat {
                    readBytes = inputStream!.read(&buffer, maxLength: buffer.capacity)
                    fullBuffer.appendContentsOf(buffer[0..<readBytes])
                    
                } while(readBytes > 0 && readBytes == 256)
                
                if fullBuffer.count > 0 {
                    do {
                        let responseId = try ResponseMessage.getResponseIdFromResponse(fullBuffer)
                        
                        if let handler: (ResponseHandler, Message) = responseHandlers[responseId] {
                            let response = try! ResponseMessage.init(collection: handler.1.collection, data: fullBuffer);
                            handler.0(reply: response)
                            responseHandlers.removeValueForKey(handler.1.requestID)
                        }
                        
                    } catch (_) {
                        responseHandlers.removeValueForKey(0)
                    }
                }
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
    
    public func sendMessage(message: Message, handler: ResponseHandler? = nil) throws {
        if !connected && outputStream == nil {
            throw MongoError.MongoDatabaseUnableToConnect
        }
        
        let messageData = try message.generateBsonMessage()
        
        if let handler: ResponseHandler = handler {
            responseHandlers[message.requestID] = (handler, message)
        }
        
        outputStream!.write(messageData, maxLength: messageData.count)
    }
}