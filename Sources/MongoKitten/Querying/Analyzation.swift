//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Dispatch
import BSON

public struct Explaination {
    public struct QueryPlanner {
        public struct Stage {
            public enum StageType: String {
                case collectionScan = "COLLSCAN"
                case indexScan = "IXSCAN"
                case fetch = "FETCH"
                case shardMerge = "SHARD_MERGE"
            }
            
            public indirect enum Children {
                case single(Stage)
                case multiple([Stage])
            }
            
            public let type: StageType
            public let children: Children?
            
            init?(_ primitive: Primitive?) {
                guard let document = Document(primitive), let stageTypeName = String(document["stage"]), let type = StageType(rawValue: stageTypeName) else {
                    return nil
                }
                
                self.type = type
                
                if let stage = Stage(document["inputStage"]) {
                    children = .single(stage)
                } else if let inputStages = Document(document["inputStages"]) {
                    var stages = [Stage]()
                    
                    for inputStage in inputStages.arrayValue {
                        guard let stage = Stage(inputStage) else {
                            return nil
                        }
                        
                        stages.append(stage)
                    }
                    
                    children = .multiple(stages)
                } else {
                    children = nil
                }
            }
        }
        
        public let namespace: String
        public let winningPlan: Stage
        
        init?(_ primitive: Primitive?) {
            guard let document = Document(primitive), let namespace = String(document["namespace"]), let winningPlan = Stage(document["winningPlan"]) else {
                return nil
            }
            
            self.namespace = namespace
            self.winningPlan = winningPlan
        }
    }
    
    public struct ExecutionStats {
        public struct Stage {
            public enum StageType: String {
                case collectionScan = "COLLSCAN"
                case indexScan = "IXSCAN"
                case fetch = "FETCH"
                case shardMerge = "SHARD_MERGE"
            }
            
            public indirect enum Children {
                case single(Stage)
            }
            
            public let type: StageType
            public let inputStage: Children?
            
            init?(_ primitive: Primitive?) {
                guard let document = Document(primitive), let stageTypeName = String(document["stage"]), let type = StageType(rawValue: stageTypeName) else {
                    return nil
                }
                
                self.type = type
                
                if let stage = Stage(document["inputStage"]) {
                    inputStage = .single(stage)
                } else {
                    self.inputStage = nil
                }
            }
        }
        
        let successful: Bool
        let returned: Int
        let executionTimeMS: Int
        let examined: (keys: Int, docs: Int)
        let stage: Stage
        
        init?(_ primitive: Primitive?) {
            guard let document = Document(primitive), let success = Bool(document["executionSuccess"]), let nReturned = Int(document["nReturned"]), let executionTime = Int(document["executionTimeMillis"]), let stage = Stage(document["executionStages"]), let totalKeysExamined = Int(document["totalKeysExamined"]), let totalDocsExamined = Int(document["totalDocsExamined"]) else {
                return nil
            }
            
            self.successful = success
            self.returned = nReturned
            self.executionTimeMS = executionTime
            self.stage = stage
            self.examined = (totalKeysExamined, totalDocsExamined)
        }
    }
    
    public let queryPlanner: QueryPlanner?
    public let executionStats: ExecutionStats?
    
    init?(_ primitive: Primitive?) {
        guard let document = Document(primitive) else {
            return nil
        }
        
        self.queryPlanner = QueryPlanner(document["queryPlanner"])
        self.executionStats = ExecutionStats(document["executionStats"])
    }
}

public class ExplainedCollection {
    /// The collection to explain
    let collection: Collection
    
    /// Creates an explained collection
    init(in collection: Collection) {
        self.collection = collection
    }
    
    /// The read concern to apply by default
    var readConcern: ReadConcern? {
        get {
            return collection.readConcern
        }
        set {
            collection.readConcern = newValue
        }
    }
    
    /// The write concern to apply by default
    var writeConcern: WriteConcern? {
        get {
            return collection.writeConcern
        }
        set {
            collection.writeConcern = newValue
        }
    }
    
    /// The collation to apply by default
    var collation: Collation? {
        get {
            return collection.collation
        }
        set {
            collection.collation = newValue
        }
    }
    
    /// The timeout to apply by default
    var timeout: DispatchTimeInterval? {
        get {
            return collection.timeout
        }
        set {
            collection.timeout = newValue
        }
    }
    
    /// The collection's full name
    var fullCollectionName: String {
        return collection.fullName
    }
    
    /// The collection's "simple" name
    var collectionName: String {
        return collection.name
    }
    
    /// The database this Collection resides in
    var database: Database {
        return collection.database
    }
    
    public func aggregate(_ pipeline: AggregationPipeline, readConcern: ReadConcern? = nil, collation: Collation? = nil, options: AggregationOptions...) throws -> Explaination {
        return try self.aggregate(pipeline, readConcern: readConcern, collation: collation, options: options)
    }
    
    public func aggregate(_ pipeline: AggregationPipeline, readConcern: ReadConcern? = nil, collation: Collation? = nil, options: [AggregationOptions]) throws -> Explaination {
        // construct command. we always use cursors in MongoKitten, so that's why the default value for cursorOptions is an empty document.
        var command: Document = ["aggregate": self.collectionName, "pipeline": pipeline.pipelineDocument, "cursor": ["batchSize": 100]]
        
        command["readConcern"] = readConcern ?? self.readConcern
        command["collation"] = collation ?? self.collation
        
        command = ["explain": command]
        
        for option in options {
            for (key, value) in option.fields {
                command[key] = value
            }
        }
        
        let reply: ServerReply
        
        let newConnection = try self.database.server.reserveConnection(writing: true, authenticatedFor: self.database)
        
        defer {
            self.database.server.returnConnection(newConnection)
        }
        
        // execute and construct cursor
        reply = try self.database.execute(command: command, using: newConnection)
        
        guard let explaination = Explaination(reply.documents.first) else {
            throw MongoError.invalidReply
        }
        
        return explaination
    }
    
    public func count(_ filter: Query? = nil, limiting limit: Int? = nil, skipping skip: Int? = nil, readConcern: ReadConcern? = nil, collation: Collation?, timeout: DispatchTimeInterval? = nil) throws -> Explaination {
        var command: Document = ["count": self.collectionName]
        
        if let filter = filter {
            command["query"] = filter
        }
        
        if let skip = skip {
            command["skip"] = Int32(skip)
        }
        
        if let limit = limit {
            command["limit"] = Int32(limit)
        }
        
        command["readConcern"] = readConcern ?? self.readConcern
        command["collation"] = collation ?? self.collation
        
        command = ["explain": command]
        
        let reply = try self.database.execute(command: command, writing: false)
        
        guard let explaination = Explaination(reply.documents.first) else {
            throw MongoError.invalidReply
        }
        
        return explaination
    }
    
    public func update(updates: [(filter: Query, to: Document, upserting: Bool, multiple: Bool)], writeConcern: WriteConcern?, ordered: Bool?, timeout: DispatchTimeInterval?) throws -> Explaination {
        guard database.server.buildInfo.version >= Version(3,0,0) else {
            throw MongoError.unsupportedFeature("Explain is not available for MongoDB <= 2.6")
        }
        
        var command: Document = ["update": self.collectionName]
        var newUpdates = [Document]()
        
        for u in updates {
            newUpdates.append([
                "q": u.filter.queryDocument,
                "u": u.to,
                "upsert": u.upserting,
                "multi": u.multiple
                ])
        }
        
        command["updates"] = Document(array: newUpdates)
        
        if let ordered = ordered {
            command["ordered"] = ordered
        }
        
        command["writeConcern"] = writeConcern ??  self.writeConcern
        
        command = ["explain": command]
        
        let reply = try self.database.execute(command: command, writing: false)
        
        guard let explaination = Explaination(reply.documents.first) else {
            throw MongoError.invalidReply
        }
        
        return explaination
    }
    
    public func remove(removals: [(filter: Query, limit: Int)], writeConcern: WriteConcern?, ordered: Bool?, timeout: DispatchTimeInterval?) throws -> Explaination {
        guard database.server.buildInfo.version >= Version(3,0,0) else {
            throw MongoError.unsupportedFeature("Explain is not available for MongoDB <= 2.6")
        }
        
        var command: Document = ["delete": self.collectionName]
        var newDeletes = [Document]()
        
        for d in removals {
            newDeletes.append([
                "q": d.filter.queryDocument,
                "limit": d.limit
                ])
        }
        
        command["deletes"] = Document(array: newDeletes)
        
        if let ordered = ordered {
            command["ordered"] = ordered
        }
        
        command["writeConcern"] = writeConcern ?? self.writeConcern
        
        command = ["explain": command]
        
        let reply = try self.database.execute(command: command, writing: false)
        
        guard let explaination = Explaination(reply.documents.first) else {
            throw MongoError.invalidReply
        }
        
        return explaination
    }
    
    public func find(_ filter: Query? = nil, sortedBy sort: Sort? = nil, projecting projection: Projection? = nil, readConcern: ReadConcern? = nil, collation: Collation? = nil, skipping skip: Int? = nil, limitedTo limit: Int? = nil, withBatchSize batchSize: Int = 100) throws -> Explaination {
        guard database.server.buildInfo.version >= Version(3,2,0) else {
            throw MongoError.unsupportedFeature("Explain is not available for MongoDB <= 3.0")
        }
        
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
        
        command = ["explain": command]
        
        let cursorConnection = try self.database.server.reserveConnection(authenticatedFor: self.collection.database)
        
        defer { self.database.server.returnConnection(cursorConnection) }
        
        let reply = try self.database.execute(command: command, until: 30, writing: false, using: cursorConnection)
        
        guard let explaination = Explaination(reply.documents.first) else {
            throw MongoError.invalidReply
        }
        
        return explaination
    }
}
