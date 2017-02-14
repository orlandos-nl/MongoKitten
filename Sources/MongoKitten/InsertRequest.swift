import Foundation

public struct InsertResponse : DatabaseResponse {
    public let identifiers: [ValueConvertible]
    public let collection: MongoCollection
}

public struct InsertRequest : WriteDatabaseRequest {
    public static let writing = false
    
    public var documents: [Document]
    public var writeConcern: WriteConcern?
    public var ordered: Bool?
    public let collection: MongoCollection
    
    public func execute() throws -> InsertResponse {
        let timeout: TimeInterval = collection.database.server.defaultTimeout + (Double(documents.count) / 50)
        
        var newIds = [ValueConvertible]()
        let protocolVersion = collection.database.server.serverData?.maxWireVersion ?? 0
        
        var position = 0
        
        while documents.count > position {
            if protocolVersion >= 2 {
                var command: Document = ["insert": collection.name]
                
                let commandDocuments = documents[position..<min(position + 1000, documents.count)].map({ (input: Document) -> ValueConvertible in
                    if let id = input[raw: "_id"] {
                        newIds.append(id)
                        return input
                    } else {
                        var output = input
                        let oid = ObjectId()
                        output[raw: "_id"] = oid
                        newIds.append(oid)
                        return output
                    }
                })
                
                position += 1000
                
                command["documents"] = Document(array: commandDocuments)
                
                if let ordered = ordered {
                    command["ordered"] = ordered
                }
                
                command[raw: "writeConcern"] = writeConcern ?? self.writeConcern
                
                let reply = try collection.database.execute(command: command, until: timeout)
                guard case .Reply(_, _, _, _, _, _, let replyDocuments) = reply else {
                    throw MongoError.insertFailure(documents: documents, error: nil)
                }
                
                guard replyDocuments.first?["ok"] as Int? == 1 && (replyDocuments.first?["writeErrors"] as Document? ?? [:]).count == 0 else {
                    throw MongoError.insertFailure(documents: documents, error: replyDocuments.first)
                }
            } else {
                let connection = try collection.database.server.reserveConnection(writing: true, authenticatedFor: collection.database)
                
                defer {
                    collection.database.server.returnConnection(connection)
                }
                
                let commandDocuments = Array(documents[position..<min(1000, documents.count)])
                position += 1000
                
                let insertMsg = Message.Insert(requestID: collection.database.server.nextMessageID(), flags: [], collection: collection, documents: commandDocuments)
                _ = try collection.database.server.send(message: insertMsg, overConnection: connection)
            }
        }
        
        return InsertResponse(identifiers: newIds, collection: collection)
    }
}

public typealias InsertHook = ((InsertRequest) throws -> ([ValueConvertible]))

extension Collection {
    @discardableResult
    public func insert(_ document: Document, applying hook: InsertHook? = nil) throws -> ValueConvertible {
        let result = try self.insert([document], applying: hook)
        
        guard let newId = result.first else {
            database.server.logger.error("No identifier could be generated")
            throw MongoError.insertFailure(documents: [document], error: nil)
        }
        
        return newId
    }
    
    @discardableResult
    public func insert(_ documents: [Document], stoppingOnError ordered: Bool? = nil, writeConcern: WriteConcern? = nil, applying hook: InsertHook? = nil) throws -> [ValueConvertible] {
        let request = InsertRequest(documents: documents, writeConcern: writeConcern, ordered: ordered, collection: self)
        
        let hook = hook ?? self.insertHook ?? DefaultHook.insertHook
        
        return try hook(request)
    }
}
