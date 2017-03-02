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
public struct AggregationPipeline: ExpressibleByArrayLiteral, ValueConvertible {
    /// The resulting Document that can be modified by the user.
    public var pipelineDocument: Document = []
    
    /// A getter for the pipeline Document.
    /// TODO: Evaluate removing access to pipelineDocument or removing this property
    public var pipeline: Document {
        return pipelineDocument
    }
    
    /// Creates a Document that can be sent to the server
    /// TODO: This is practically useless now as the conforming protocol has been removed.
    public func makeDocument() -> Document {
        return self.pipelineDocument
    }
    
    /// Allows embedding this pipeline inside another Document
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.pipelineDocument
    }
    
    /// You can easily and naturally create an aggregate by providing a variadic list of stages.
    public init(arrayLiteral elements: Stage...) {
        self.pipelineDocument = Document(array: elements.map {
            $0.makeDocument()
        })
    }
    
    /// You can easily and naturally create an aggregate by providing an array of stages.
    public init(arrayLiteral elements: [Stage]) {
        self.pipelineDocument = Document(array: elements.map {
            $0.makeDocument()
        })
    }
    
    /// Appends a stage to this pipeline
    public mutating func append(_ stage: Stage) {
        self.pipelineDocument.append(stage)
    }
    
    /// Creates an empty pipeline
    public init() { }
    
    /// Create a pipeline from a Document
    public init(_ document: Document) {
        self.pipelineDocument = document
    }
    
    /// A Pipeline stage. Pipelines pass their data of the collection through every stage. The last stage defines the output.
    ///
    /// The input are all Documents in the collection.
    ///
    /// The input of stage 2 is the output of stage 3 and so on..
    public struct Stage: ValueConvertible {
        /// Allows embedding this stage inside another Document
        public func makeBSONPrimitive() -> BSONPrimitive {
            return self.document
        }
        
        /// The Document that this stage consists of
        public func makeDocument() -> Document {
            return self.document
        }
        
        /// The resulting Document that this Stage consists of
        var document: Document
        
        /// Create a stage from a Document
        public init(_ document: Document) {
            self.document = document
        }
        
        /// A projection stage passes only the projected fields to the next stage.
        @discardableResult
        public static func projecting(_ projection: Projection) -> Stage {
            return Stage([
                "$project": projection
                ] as Document)
        }
        
        /// A match stage only passed the documents that match the query to the next stage
        @discardableResult
        public static func matching(_ query: Query) -> Stage {
            return Stage([
                "$match": query
                ] as Document)
        }
        
        /// A match stage only passed the documents that match the query to the next stage
        @discardableResult
        public static func matching(_ query: Document) -> Stage {
            return Stage([
                "$match": query
                ] as Document)
        }
        
        /// Takes a sample with the size of `size`. These randomly selected Documents will be passed to the next stage.
        @discardableResult
        public static func sample(sizeOf size: Int) -> Stage {
            return Stage([
                "$sample": ["size": size] as Document
                ] as Document)
        }
        
        /// This will skip the specified number of input Documents and leave them out. The rest will be passed to the next stage.
        @discardableResult
        public static func skipping(_ skip: Int) -> Stage {
            return Stage([
                "$skip": skip
                ] as Document)
        }
        
        /// This will limit the results to the specified number.
        ///
        /// The first Documents will be selected.
        /// 
        /// Anything after that will be discarted and will not be sent to the next stage.
        @discardableResult
        public static func limitedTo(_ limit: Int) -> Stage {
            return Stage([
                "$limit": limit
                ] as Document)
        }
        
        /// Sorts the input Documents by the specified `Sort` object and passed them in the newly sorted order to the next stage.
        @discardableResult
        public static func sortedBy(_ sort: Sort) -> Stage {
            return Stage([
                "$sort": sort
                ] as Document)
        }
        
        /// Groups the input Documents by the specified expression and outputs a Document to the next stage for each distinct grouping.
        ///
        /// This form accepts a Document for more flexiblity.
        ///
        /// https://docs.mongodb.com/manual/reference/operator/aggregation/group/
        @discardableResult
        public static func grouping(groupDocument: Document) -> Stage {
            return Stage([
                "$group": groupDocument
                ] as Document)
        }
        
        /// Groups the input Documents by the specified expression and outputs a Document to the next stage for each distinct grouping.
        ///
        /// This form accepts predefined options and works for almost all scenarios.
        ///
        /// https://docs.mongodb.com/manual/reference/operator/aggregation/group/
        @discardableResult
        public static func grouping(_ id: ExpressionRepresentable, computed computedFields: [String: AccumulatedGroupExpression] = [:]) -> Stage {
            let groupDocument = computedFields.reduce([:] as Document) { (doc, expressionPair) -> Document in
                guard expressionPair.key != "_id" else {
                    return doc
                }
                
                var doc = doc
                
                doc[expressionPair.key] = expressionPair.value.makeDocument()
                
                doc[raw: "_id"] = id.makeExpression()
                
                return doc
            }
            
            return Stage([
                "$group": groupDocument
                ] as Document)
        }
        
        /// Deconstructs an Array at the given path (key).
        ///
        /// https://docs.mongodb.com/manual/reference/operator/aggregation/unwind/#pipe._S_unwind
        @discardableResult
        public static func unwind(atPath path: String, includeArrayIndex: String? = nil, preserveNullAndEmptyArrays: Bool? = nil) -> Stage {
            let unwind: ValueConvertible
            
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
                    ] as Document
            } else {
                unwind = path
            }
            
            return Stage([
                "$unwind": unwind
                ] as Document)
        }
        
        /// Performs a left outer join to an unsharded collection in the same database
        @discardableResult
        public static func lookup(fromCollection from: String, localField: String, foreignField: String, as: String) -> Stage {
            return Stage([
                "$lookup": [
                    "from": from,
                    "localField": localField,
                    "foreignField": foreignField,
                    "as": `as`
                    ] as Document
                ] as Document)
        }
        
        /// Performs a left outer join to an unsharded collection in the same database
        @discardableResult
        public static func lookup(fromCollection from: Collection, localField: String, foreignField: String, as: String) -> Stage {
            return Stage([
                "$lookup": [
                    "from": from.name,
                    "localField": localField,
                    "foreignField": foreignField,
                    "as": `as`
                    ] as Document
                ] as Document)
        }
        
        /// Writes the resulting Documents to the provided Collection
        @discardableResult
        public static func writeOutput(toCollection collection: Collection) -> Stage {
            return self.writeOutput(toCollectionNamed: collection.name)
        }
        
        /// Writes the resulting Documents to the provided Collection
        @discardableResult
        public static func writeOutput(toCollectionNamed collectionName: String) -> Stage {
            return Stage([
                "$out": collectionName
                ] as Document)
        }
        
        /// Takes the input Documents and passes them through multiple Aggregation Pipelines. Every pipeline result will be placed at the provided key.
        @discardableResult
        public static func facet(_ facet: [String: AggregationPipeline]) -> Stage {
            return Stage([
                "$facet": Document(dictionaryElements: facet.map {
                    ($0.0, $0.1)
                })
                ] as Document)
        }
        
        /// Counts the amounts of Documents that have been inputted. Places the result at the provided key.
        @discardableResult
        public static func counting(insertedAtKey key: String) -> Stage {
            return Stage([
                "$count": key
                ] as Document)
        }
        
        /// Takes an embedded Document resulting from the provided expression and replaces the entire Document with this result.
        ///
        /// You can take an embedded Document at a lower level of this Document and make it the new root.
        @discardableResult
        public static func replaceRoot(withExpression expression: ExpressionRepresentable) -> Stage {
            return Stage([
                "$replaceRoot": [
                    "newRoot": expression.makeExpression()
                    ] as Document
                ] as Document)
        }
        
        /// Adds fields to the inputted Documents and sends these new Documents to the next stage.
        @discardableResult
        public static func addingFields(_ fields: [String: ExpressionRepresentable]) -> Stage {
            return Stage([
                "$addFields": Document(dictionaryElements: fields.map {
                    ($0.0, $0.1.makeExpression())
                })
                ] as Document)
        }

        /// Runs a geospatial query on the inputted Documents
        ///
        /// Outputs all documents that are near the provided location in the options matching the parameters
        @discardableResult
        public static func geoNear(geoNearOption: GeoNearOption) -> Stage {
            return Stage(["$geoNear": geoNearOption] as Document)
        }
    }
}

/// The expressions are currently only supporting literals.
public enum Expression: ValueConvertible {
    /// A literal value
    ///
    /// Any String starting with a `$` will be seen as a pointer to a Document key. In this case the value at that key will be used instead.
    case literal(ValueConvertible)
    
    /// Converts an expression to a BSONPrimitive for easy embedding in Documents
    public func makeBSONPrimitive() -> BSONPrimitive {
        switch self {
        case .literal(let val):
            return val.makeBSONPrimitive()
        }
    }
}

/// Objects conforming to this are represetnable as an Expression
public protocol ExpressionRepresentable {
    /// Creates an Expression from this object
    func makeExpression() -> Expression
}

/// Converts String to a literal Expression
extension String: ExpressionRepresentable {
    /// Converts String to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts Bool to a literal Expression
extension Bool: ExpressionRepresentable {
    /// Converts Bool to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts ObjectId to a literal Expression
extension ObjectId: ExpressionRepresentable {
    /// Converts ObjectId to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts Binary to a literal Expression
extension Binary: ExpressionRepresentable {
    /// Converts Binary to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts Null to a literal Expression
extension Null: ExpressionRepresentable {
    /// Converts Null to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts JavascriptCode to a literal Expression
extension JavascriptCode: ExpressionRepresentable {
    /// Converts JavascriptCode to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts String to a literal Expression
extension RegularExpression: ExpressionRepresentable {
    /// Converts String to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts Date to a literal Expression
extension Date: ExpressionRepresentable {
    /// Converts Date to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts Double to a literal Expression
extension Double: ExpressionRepresentable {
    /// Converts Double to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts Int to a literal Expression
extension Int: ExpressionRepresentable {
    /// Converts Int to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts Int32 to a literal Expression
extension Int32: ExpressionRepresentable {
    /// Converts Int32 to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts Int64 to a literal Expression
extension Int64: ExpressionRepresentable {
    /// Converts Int64 to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// Converts Document to a literal Expression
extension Document: ExpressionRepresentable {
    /// Converts Document to a literal Expression
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

/// All Accumulated Group Expressions used for the group aggregation stage
public enum AccumulatedGroupExpression {
    /// A sum of multiple expressions (results)
    case sum([ExpressionRepresentable])
    
    /// The average of multiple expressions (results). When a
    case average([ExpressionRepresentable])
    
    /// The highest number among multiple expression (results)
    case max([ExpressionRepresentable])
    
    /// The lowest number among multiple expression (results)
    case min([ExpressionRepresentable])
    
    /// Returns the value that results from applying an expression to the first document in a group of documents.
    ///
    /// When a field is selected, the first Document's value at this key will be used.
    case first(ExpressionRepresentable)
    
    /// Returns the value that results from applying an expression to the last document in a group of documents.
    ///
    /// When a field is selected, the last Document's value at this key will be used.
    case last(ExpressionRepresentable)
    
    /// Returns an array of all values that result from applying an expression to each document in a group of documents that share the same group by key.
    ///
    /// https://docs.mongodb.com/manual/reference/operator/aggregation/push/
    ///
    /// WARNING: Only available in a group(ed) stage
    case push(ExpressionRepresentable)
    
    /// Returns an array of all unique values that results from applying an expression to each document in a group of documents that share the same group by key.
    ///
    /// https://docs.mongodb.com/manual/reference/operator/aggregation/addToSet/
    case addToSet(ExpressionRepresentable)
    
    // TODO: Implement https://docs.mongodb.com/manual/reference/operator/aggregation/stdDevPop/#grp._S_stdDevPop
    // TODO: Implement https://docs.mongodb.com/manual/reference/operator/aggregation/stdDevSamp/#grp._S_stdDevSamp
    
    // MARK: Helpers
    
    /// Creates a sum expression. Can contain one or more values.
    ///
    /// The result of this operator is the sum of all provided resulting values (when multiple are entered).
    ///
    /// All results must be numbers
    ///
    /// When a single expression is provided it will be regarded as a literal rather than an array and is useful when providing a selector for a field.
    ///
    /// When multiple expressions are provided this will be regarded as an array of expressions resulting in a number.
    public static func sumOf(_ expressions: ExpressionRepresentable...) -> AccumulatedGroupExpression {
        return .sum(expressions)
    }
    
    /// Creates a sum expression. Can contain one or more values.
    ///
    /// The result of this operator is the sum of all provided resulting values (when multiple are entered).
    ///
    /// All results must be numbers
    ///
    /// When a single expression is provided it will be regarded as a literal rather than an array and is useful when providing a selector for a field.
    ///
    /// When multiple expressions are provided this will be regarded as an array of expressions resulting in a number.
    public static func sumOf(_ expressions: [ExpressionRepresentable]) -> AccumulatedGroupExpression {
        return .sum(expressions)
    }
    
    /// Creates a avg expression. Can contain one or more values.
    ///
    /// The result of this operator is the average of all provided resulting values (when multiple are entered).
    ///
    /// All results must be numbers
    ///
    /// When a single expression is provided it will be regarded as a literal rather than an array and is useful when providing a selector for a field.
    ///
    /// When multiple expressions are provided this will be regarded as an array of expressions resulting in a number.
    public static func averageOf(_ expressions: ExpressionRepresentable...) -> AccumulatedGroupExpression {
        return .average(expressions)
    }
    
    /// Creates a avg expression. Can contain one or more values.
    ///
    /// The result of this operator is the average of all provided resulting values (when multiple are entered).
    ///
    /// All results must be numbers
    ///
    /// When a single expression is provided it will be regarded as a literal rather than an array and is useful when providing a selector for a field.
    ///
    /// When multiple expressions are provided this will be regarded as an array of expressions resulting in a number.
    public static func averageOf(_ expressions: [ExpressionRepresentable]) -> AccumulatedGroupExpression {
        return .average(expressions)
    }
    
    /// Creates a min expression. Can contain one or more values.
    ///
    /// The result of this operator is the smallest number amongst all provided resulting values (when multiple are entered).
    ///
    /// All results must be numbers
    ///
    /// When a single expression is provided it will be regarded as a literal rather than an array and is useful when providing a selector for a field.
    ///
    /// When multiple expressions are provided this will be regarded as an array of expressions resulting in a number.
    public static func minOf(_ expressions: ExpressionRepresentable...) -> AccumulatedGroupExpression {
        return .min(expressions)
    }
    
    /// Creates a min expression. Can contain one or more values.
    ///
    /// The result of this operator is the smallest number amongst all provided resulting values (when multiple are entered).
    ///
    /// All results must be numbers
    ///
    /// When a single expression is provided it will be regarded as a literal rather than an array and is useful when providing a selector for a field.
    ///
    /// When multiple expressions are provided this will be regarded as an array of
    public static func minOf(_ expressions: [ExpressionRepresentable]) -> AccumulatedGroupExpression {
        return .min(expressions)
    }
    
    /// Creates a max expression. Can contain one or more values.
    ///
    /// The result of this operator is the biggest number amongst all provided resulting values (when multiple are entered).
    ///
    /// All results must be numbers
    ///
    /// When a single expression is provided it will be regarded as a literal rather than an array and is useful when providing a selector for a field.
    ///
    /// When multiple expressions are provided this will be regarded as an array of
    public static func maxOf(_ expressions: ExpressionRepresentable...) -> AccumulatedGroupExpression {
        return .max(expressions)
    }
    
    /// Creates a max expression. Can contain one or more values.
    ///
    /// The result of this operator is the biggest number amongst all provided resulting values (when multiple are entered).
    ///
    /// All results must be numbers
    ///
    /// When a single expression is provided it will be regarded as a literal rather than an array and is useful when providing a selector for a field.
    ///
    /// When multiple expressions are provided this will be regarded as an array of
    public static func maxOf(_ expressions: [ExpressionRepresentable]) -> AccumulatedGroupExpression {
        return .max(expressions)
    }
    
    // MARK: Converting
    
    /// Converts this `AccumulatedGroupExpression` to a BSONPrimitive so that it can be embedded inside a Document easily
    public func makeBSONPrimitive() -> BSONPrimitive {
        return makeDocument()
    }
    
    /// Converts this `AccumulatedGroupExpression` to a Document operator for MongoDB
    public func makeDocument() -> Document {
        switch self {
        case .sum(let expressions):
            if expressions.count == 1, let expression = expressions.first {
                return [
                    "$sum": expression.makeExpression()
                ]
            } else {
                return [
                    "$sum": Document(array: expressions.map {
                        $0.makeExpression()
                    })
                ]
            }
        case .average(let expressions):
            if expressions.count == 1, let expression = expressions.first {
                return [
                    "$avg": expression.makeExpression()
                ]
            } else {
                return [
                    "$avg": Document(array: expressions.map {
                        $0.makeExpression()
                    })
                ]
            }
        case .first(let expression):
            return [
                "$first": expression.makeExpression()
            ]
        case .last(let expression):
            return [
                "$last": expression.makeExpression()
            ]
        case .push(let expression):
            return [
                "$push": expression.makeExpression()
            ]
        case .addToSet(let expression):
            return [
                "$addToSet": expression.makeExpression()
            ]
        case .max(let expressions):
            if expressions.count == 1, let expression = expressions.first {
                return [
                    "$max": expression.makeExpression()
                ]
            } else {
                return [
                    "$max": Document(array: expressions.map {
                        $0.makeExpression()
                    })
                ]
            }
        case .min(let expressions):
            if expressions.count == 1, let expression = expressions.first {
                return [
                    "$min": expression.makeExpression()
                ]
            } else {
                return [
                    "$min": Document(array: expressions.map {
                        $0.makeExpression()
                    })
                ]
            }
        }
    }
}
