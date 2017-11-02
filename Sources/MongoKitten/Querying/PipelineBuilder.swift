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
import BSON

/// A Pipeline used for aggregation queries
public struct AggregationPipeline: ExpressibleByArrayLiteral, Codable {
    public func encode(to encoder: Encoder) throws {
        try stages.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        self.stages = try [Stage](from: decoder)
    }
    
    /// The resulting Document that can be modified by the user.
    public var stages = [Stage]()
    
    /// You can easily and naturally create an aggregate by providing a variadic list of stages.
    public init(arrayLiteral elements: Stage...) {
        self.stages = elements
    }
    
    /// You can easily and naturally create an aggregate by providing an array of stages.
    public init(arrayLiteral elements: [Stage]) {
        self.stages = elements
    }
    
    /// Appends a stage to this pipeline
    public mutating func append(_ stage: Stage) {
        self.stages.append(stage)
    }
    
    /// Creates an empty pipeline
    public init() { }
    
    /// Create a pipeline from a Document
    public init(_ document: Document) {
        self.stages = document.arrayRepresentation.flatMap(Document.init).map(Stage.init)
    }
    
    /// A Pipeline stage. Pipelines pass their data of the collection through every stage. The last stage defines the output.
    ///
    /// The input are all Documents in the collection.
    ///
    /// The input of stage 2 is the output of stage 3 and so on..
    public struct Stage: Codable {
        /// The resulting Document that this Stage consists of
        var document: Document
        
        public func encode(to encoder: Encoder) throws {
            try self.document.encode(to: encoder)
        }
        
        public init(from decoder: Decoder) throws {
            self.document = try Document(from: decoder)
        }
        
        /// Create a stage from a Document
        public init(_ document: Document) {
            self.document = document
        }
        
        /// A projection stage passes only the projected fields to the next stage.
        public static func project(_ projection: Projection) -> Stage {
            return Stage([
                "$project": projection.document
            ])
        }
        
        /// A match stage only passed the documents that match the query to the next stage
        public static func match(_ query: Query) -> Stage {
            return Stage([
                "$match": query.document
            ])
        }
        
        /// Takes a sample with the size of `size`. These randomly selected Documents will be passed to the next stage.
        public static func sample(sizeOf size: Int) -> Stage {
            return Stage([
                "$sample": ["size": size]
            ])
        }
        
        /// This will skip the specified number of input Documents and leave them out. The rest will be passed to the next stage.
        public static func skip(_ skip: Int) -> Stage {
            return Stage([
                "$skip": skip
            ])
        }
        
        /// This will limit the results to the specified number.
        ///
        /// The first Documents will be selected.
        ///
        /// Anything after that will be discarted and will not be sent to the next stage.
        public static func limit(_ limit: Int) -> Stage {
            return Stage([
                "$limit": limit
            ])
        }
        
        /// Sorts the input Documents by the specified `Sort` object and passed them in the newly sorted order to the next stage.
        public static func sort(_ sort: Sort) -> Stage {
            return Stage([
                "$sort": sort.document
            ])
        }
        
        /// Groups the input Documents by the specified expression and outputs a Document to the next stage for each distinct grouping.
        ///
        /// This form accepts a Document for more flexiblity.
        ///
        /// https://docs.mongodb.com/manual/reference/operator/aggregation/group/
        public static func group(groupDocument: Document) -> Stage {
            return Stage([
                "$group": groupDocument
            ])
        }
        
        /// Groups the input Documents by the specified expression and outputs a Document to the next stage for each distinct grouping.
        ///
        /// This form accepts predefined options and works for almost all scenarios.
        ///
        /// https://docs.mongodb.com/manual/reference/operator/aggregation/group/
        public static func group(_ id: Primitive, computed computedFields: [String: Primitive] = [:]) -> Stage {
            let groupDocument = computedFields.reduce([:]) { (doc, expressionPair) -> Document in
                guard expressionPair.key != "_id" else {
                    return doc
                }
                
                var doc = doc
                
                doc[expressionPair.key] = expressionPair.value
                
                doc["_id"] = id
                
                return doc
            }
            
            return Stage([
                "$group": groupDocument
                ])
        }
        
        /// Deconstructs an Array at the given path (key).
        ///
        /// https://docs.mongodb.com/manual/reference/operator/aggregation/unwind/#pipe._S_unwind
        public static func unwind(_ path: String, includeArrayIndex: String? = nil, preserveNullAndEmptyArrays: Bool? = nil) -> Stage {
            let unwind: BSON.Primitive
            
            if let includeArrayIndex = includeArrayIndex {
                var unwind1 = [
                    "path": path
                    ] as Document
                
                unwind1["includeArrayIndex"] = includeArrayIndex
                
                if let preserveNullAndEmptyArrays = preserveNullAndEmptyArrays {
                    unwind1["preserveNullAndEmptyArrays"] = preserveNullAndEmptyArrays
                }
                
                unwind = unwind1
            } else if let preserveNullAndEmptyArrays = preserveNullAndEmptyArrays {
                unwind = [
                    "path": path,
                    "preserveNullAndEmptyArrays": preserveNullAndEmptyArrays
                ]
            } else {
                unwind = path
            }
            
            return Stage([
                "$unwind": unwind
                ])
        }
        
        /// Performs a left outer join to an unsharded collection in the same database
        public static func lookup(from collection: String, localField: String, foreignField: String, as: String) -> Stage {
            return Stage([
                "$lookup": [
                    "from": collection,
                    "localField": localField,
                    "foreignField": foreignField,
                    "as": `as`
                ]
                ])
        }
        
        /// Performs a left outer join to an unsharded collection in the same database
        public static func lookup(from collection: Collection, localField: String, foreignField: String, as: String) -> Stage {
            return Stage([
                "$lookup": [
                    "from": collection.name,
                    "localField": localField,
                    "foreignField": foreignField,
                    "as": `as`
                ]
                ])
        }
        
        /// Writes the resulting Documents to the provided Collection
        public static func out(to collection: Collection) -> Stage {
            return self.out(to: collection.name)
        }
        
        /// Writes the resulting Documents to the provided Collection
        public static func out(to collectionName: String) -> Stage {
            return Stage([
                "$out": collectionName
                ])
        }
        
        /// Takes the input Documents and passes them through multiple Aggregation Pipelines. Every pipeline result will be placed at the provided key.
        public static func facet(_ facet: [String: AggregationPipeline]) -> Stage {
            return Stage([
                "$facet": facet
            ])
        }
        
        /// Counts the amounts of Documents that have been inputted. Places the result at the provided key.
        public static func count(insertedAtKey key: String) -> Stage {
            return Stage([
                "$count": key
            ])
        }
        
        /// Takes an embedded Document resulting from the provided expression and replaces the entire Document with this result.
        ///
        /// You can take an embedded Document at a lower level of this Document and make it the new root.
        public static func replaceRoot(withExpression expression: Primitive) -> Stage {
            return Stage([
                "$replaceRoot": [
                    "newRoot": expression
                ]
            ])
        }
        
        /// Adds fields to the inputted Documents and sends these new Documents to the next stage.
        public static func addFields(_ fields: [String: Primitive]) -> Stage {
            return Stage([
                "$addFields": Document(dictionaryElements: fields.map {
                    ($0.0, $0.1)
                })
            ])
        }
    }
}
