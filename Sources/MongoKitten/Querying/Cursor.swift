//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
import BSON

public typealias BasicCursor = Cursor<Document>

public class Cursor<T> : Sequence {
    public let collection: Collection
    
    public var filter: Query?
    
    public typealias Transformer = (Document) -> (T?)
    
    public let transform: Transformer
    
    public func count(limitedTo limit: Int? = nil, skipping skip: Int? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil) throws -> Int {
        var command: Document = ["count": collection.name]
        
        if let filter = filter {
            command["query"] = filter
        }
        
        if let skip = skip {
            command["skip"] = Int32(skip)
        }
        
        if let limit = limit {
            command["limit"] = Int32(limit)
        }
        
        command["readConcern"] = readConcern ?? collection.readConcern
        command["collation"] = collation ?? collection.collation
        
        let reply = try collection.database.execute(command: command, writing: false)
        
        guard case .Reply(_, _, _, _, _, _, let documents) = reply, let document = documents.first else {
            throw InternalMongoError.incorrectReply(reply: reply)
        }
        
        guard let n = Int(document["n"]), Int(document["ok"]) == 1 else {
            throw InternalMongoError.incorrectReply(reply: reply)
        }
        
        return n
    }
    
    public func findOne(sortedBy sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil) throws -> T? {
        return try self.find(sortedBy: sort, projecting: projection, readConcern: readConcern, collation: collation, skipping: skip, limitedTo: 1, withBatchSize: 1).next()
    }
    
    public var first: T? {
        do {
            return try findOne()
        } catch {
            return nil
        }
    }
    
    public func find(sortedBy sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil, limitedTo limit: Int? = nil, withBatchSize batchSize: Int = 100) throws -> AnyIterator<T> {
        precondition(batchSize < Int(Int32.max))
        precondition(skip ?? 0 < Int(Int32.max))
        precondition(limit ?? 0 < Int(Int32.max))
        
        if collection.database.server.buildInfo.version >= Version(3,2,0) {
            var command: Document = [
                "find": collection.name,
                "readConcern": readConcern ?? collection.readConcern,
                "collation": collation ?? collection.collation,
                "batchSize": Int32(batchSize)
            ]
            
            if let filter = filter {
                command["filter"] = filter
            }
            
            if let sort = sort {
                command["sort"] = sort
            }
            
            if let projection = projection {
                command["projection"] = projection
            }
            
            if let skip = skip {
                command["skip"] = Int32(skip)
            }
            
            if let limit = limit {
                command["limit"] = Int32(limit)
            }
            
            let reply = try collection.database.execute(command: command, writing: false)
            
            guard case .Reply(_, _, _, _, _, _, let documents) = reply else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            guard let responseDoc = documents.first, let cursorDoc = responseDoc["cursor"] as? Document else {
                throw MongoError.invalidResponse(documents: documents)
            }
            
            let cursor = try _Cursor(cursorDocument: cursorDoc, collection: collection, chunkSize: Int32(batchSize), transform: { doc in
                return doc
            })
            
            return _Cursor(base: cursor) {
                self.transform($0)
            }.makeIterator()
        } else {
            let connection = try collection.database.server.reserveConnection(authenticatedFor: collection.database)
            
            defer {
                collection.database.server.returnConnection(connection)
            }
            
            let queryMsg = Message.Query(requestID: collection.database.server.nextMessageID(), flags: [], collection: collection, numbersToSkip: Int32(skip) ?? 0, numbersToReturn: Int32(batchSize), query: filter?.queryDocument ?? [], returnFields: projection?.document)
            
            let reply = try collection.database.server.sendAndAwait(message: queryMsg, overConnection: connection)
            
            guard case .Reply(_, _, _, let cursorID, _, _, var documents) = reply else {
                throw InternalMongoError.incorrectReply(reply: reply)
            }
            
            if let limit = limit {
                if documents.count > Int(limit) {
                    documents.removeLast(documents.count - Int(limit))
                }
            }
            
            var returned: Int = 0
            
            let cursor = _Cursor(namespace: collection.fullName, collection: collection, cursorID: cursorID, initialData: documents, chunkSize: Int32(batchSize), transform: { doc in
                if let limit = limit {
                    guard returned < limit else {
                        return nil
                    }
                    
                    returned += 1
                }
                return doc
            })
            
            return _Cursor(base: cursor) {
                self.transform($0)
            }.makeIterator()
        }
    }
    
    public func update(to document: Document, upserting: Bool, multiple: Bool, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try collection.update(matching: filter ?? [:], to: document, upserting: upserting, multiple: multiple, writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    @discardableResult
    public func remove(limitedTo limit: Int = 0, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try collection.remove(matching: filter ?? [:], limitedTo: limit, writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    public func flatMap<B>(transform: @escaping (T) -> (B?)) -> Cursor<B> {
        return Cursor<B>(base: self, transform: transform)
    }
    
    public init<B>(base: Cursor<B>, transform: @escaping (B) -> (T?)) {
        self.collection = base.collection
        self.filter = base.filter
        self.transform = {
            if let bValue = base.transform($0) {
                return transform(bValue)
            } else {
                return nil
            }
        }
    }
    
    public func makeIterator() -> AnyIterator<T> {
        do {
            return try find()
        } catch {
            return AnyIterator { nil }
        }
    }
    
    public init(`in` collection: Collection, `where` filter: Query? = nil, transform: @escaping Transformer) {
        self.collection = collection
        self.filter = filter
        self.transform = transform
    }
}

extension Cursor where T == Document {
    public convenience init(`in` collection: Collection, `where` filter: Query? = nil) {
        self.init(in: collection, where: filter) { $0 }
    }
}
