import BSON

public struct FindResponse : DatabaseResponse {
    public let collection: MongoCollection
    public let batchSize: Int32
    public let cursor: Cursor<Document>
    
    init(from message: Message, in collection: Collection, batchSize: Int32) throws {
        guard case .Reply(_, _, _, _, _, _, let documents) = message else {
            throw InternalMongoError.incorrectReply(reply: message)
        }
        
        guard let responseDocument = documents.first, let cursorDocument = responseDocument["cursor"] as Document? else {
            throw MongoError.invalidResponse(documents: documents)
        }
        
        self.collection = collection
        self.batchSize = batchSize
        self.cursor = try Cursor(cursorDocument: cursorDocument, collection: collection, chunkSize: batchSize) { doc in
            return doc
        }
    }
    
    init(from cursor: Cursor<Document>, in collection: Collection, batchSize: Int32) {
        self.collection = collection
        self.batchSize = batchSize
        self.cursor = cursor
    }
}

public struct FindRequest : ReadDatabaseRequest {
    public static let writing = false
    
    public var filter: Query?
    public var sort: Sort?
    public var projection: Projection?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    public var limit: Int?
    public var skip: Int?
    public var batchSize: Int
    public let collection: MongoCollection
    
    public typealias Response = FindResponse
    
    public func execute() throws -> FindResponse {
        if collection.database.server.buildInfo.version >= Version(3,2,0) {
            let response = try collection.database.execute(command: try makeCommandDocument())
            
            return try Response(from: response, in: collection, batchSize: Int32(batchSize))
        } else {
            let connection = try collection.database.server.reserveConnection(authenticatedFor: collection.database)
            
            defer {
                collection.database.server.returnConnection(connection)
            }
            
            let queryMsg = Message.Query(requestID: collection.database.server.nextMessageID(), flags: [], collection: collection, numbersToSkip: Int32(skip ?? 0), numbersToReturn: Int32(batchSize), query: filter?.queryDocument ?? [], returnFields: projection?.document)
            
            let reply = try collection.database.server.sendAndAwait(message: queryMsg, overConnection: connection)
            
            guard case .Reply(_, _, _, let cursorID, _, _, var documents) = reply else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            if let limit = limit {
                if documents.count > Int(limit) {
                    documents.removeLast(documents.count - Int(limit))
                }
            }
            
            var returned = 0
            
            let cursor = Cursor(namespace: collection.fullName, collection: collection, cursorID: cursorID, initialData: documents, chunkSize: Int32(batchSize), transform: { doc in
                if let limit = self.limit {
                    guard returned < limit else {
                        return nil
                    }
                    
                    returned += 1
                }
                return doc
            })
            
            return Response(from: cursor, in: collection, batchSize: Int32(batchSize))
        }
    }
    
    internal func makeCommandDocument() throws -> Document {
        guard batchSize <= maxInt32 else {
            throw MongoError.integerOverInt32
        }
        
        var command: Document = [
            "find": collection.name,
            "batchSize": Int32(batchSize),
            "readConcern": readConcern ?? collection.readConcern,
            "collation": collation ?? collection.collation
        ]
        
        if let limit = limit {
            guard limit <= maxInt32 else {
                throw MongoError.integerOverInt32
            }
        }
        
        if let filter = filter {
            command[raw: "filter"] = filter
        }
        
        if let sort = sort {
            command[raw: "sort"] = sort
        }
        
        if let projection = projection {
            command[raw: "projection"] = projection
        }
        
        if let skip = skip {
            command["skip"] = Int32(skip)
        }
        
        return command
    }
}

public typealias FindHook = ((FindRequest) throws -> (Cursor<Document>))

extension Collection {
    public func findOne(matching filter: Query? = nil, sortedBy sort: Sort? = nil, projecting projection: Projection? = nil, skipping skip: Int? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, applying hook: FindHook? = nil) throws -> Document? {
        return try self.find(matching: filter, sortingBy: sort, projecting: projection, skipping: skip, limitingTo: 1, readConcern: readConcern, collation: collation, applying: hook).next()
    }
    
    public func find(matching filter: Query? = nil, sortingBy sort: Sort? = nil, projecting projection: Projection? = nil, skipping skip: Int? = nil, limitingTo limit: Int? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, inBatchesOf batchSize: Int = 100, applying hook: FindHook? = nil) throws -> Cursor<Document> {
        precondition(batchSize <= maxInt32, "The provided batchSize must be smaller than Int32.max")
        precondition(limit ?? 0 <= maxInt32, "The provided limit must be smaller than Int32.max")
        precondition(skip ?? 0 <= maxInt32, "The provided skip must be smaller than Int32.max")
        
        let request = FindRequest(filter: filter, sort: sort, projection: projection, readConcern: readConcern, collation: collation, limit: limit, skip: skip, batchSize: batchSize, collection: self)
        
        let hook = hook ?? self.findHook ?? DefaultHook.findHook
        
        return try hook(request)
    }
}
