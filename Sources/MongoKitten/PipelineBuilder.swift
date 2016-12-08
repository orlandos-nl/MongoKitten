import Foundation
import BSON

public struct Pipeline: ExpressibleByArrayLiteral, ValueConvertible {
    public var pipelineDocument: Document = []
    
    public var pipeline: Document {
        return pipelineDocument
    }
    
    public func makeDocument() -> Document {
        return self.pipelineDocument
    }
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.pipelineDocument
    }
    
    public init(arrayLiteral elements: Stage...) {
        self.pipelineDocument = Document(array: elements.map {
            $0.makeDocument()
        })
    }
    
    public init() { }
    
    public struct Stage: ValueConvertible {
        public func makeBSONPrimitive() -> BSONPrimitive {
            return self.document
        }
        
        public func makeDocument() -> Document {
            return self.document
        }
        
        var document: Document
        
        init(_ document: Document) {
            self.document = document
        }
        
        @discardableResult
        public static func projecting(_ projection: Projection) -> Stage {
            return Stage([
                "$project": projection
                ] as Document)
        }
        
        @discardableResult
        public static func matching(_ query: Query) -> Stage {
            return Stage([
                "$match": query
                ] as Document)
        }
        
        @discardableResult
        public static func matching(_ query: Document) -> Stage {
            return Stage([
                "$match": query
                ] as Document)
        }
        
        @discardableResult
        public static func sample(sizeOf size: Int) -> Stage {
            return Stage([
                "$sample": ["size": size] as Document
                ] as Document)
        }
        
        @discardableResult
        public static func skipping(_ skip: Int) -> Stage {
            return Stage([
                "$skip": skip
                ] as Document)
        }
        
        @discardableResult
        public static func limitedTo(_ limit: Int) -> Stage {
            return Stage([
                "$limit": limit
                ] as Document)
        }
        
        @discardableResult
        public static func sortedBy(_ sort: Sort) -> Stage {
            return Stage([
                "$sort": sort
                ] as Document)
        }
        
        @discardableResult
        public static func grouping(groupDocument: Document) -> Stage {
            return Stage([
                "$group": groupDocument
                ] as Document)
        }
        
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
        
        @discardableResult
        public static func writeOutput(toCollection collection: Collection) -> Stage {
            return self.writeOutput(toCollectionNamed: collection.name)
        }
        
        @discardableResult
        public static func writeOutput(toCollectionNamed collectionName: String) -> Stage {
            return Stage([
                "$out": collectionName
                ] as Document)
        }
        
        @discardableResult
        public static func facet(_ facet: [String: Pipeline]) -> Stage {
            return Stage([
                "$facet": Document(dictionaryElements: facet.map {
                    ($0.0, $0.1)
                })
                ] as Document)
        }
        
        @discardableResult
        public static func counting(insertedAtKey key: String) -> Stage {
            return Stage([
                "$count": key
                ] as Document)
        }
        
        @discardableResult
        public static func replaceRoot(withExpression expression: ExpressionRepresentable) -> Stage {
            return Stage([
                "$replaceRoot": [
                    "newRoot": expression.makeExpression()
                    ] as Document
                ] as Document)
        }
        
        @discardableResult
        public static func addingFields(_ fields: [String: ExpressionRepresentable]) -> Stage {
            return Stage([
                "$addFields": Document(dictionaryElements: fields.map {
                    ($0.0, $0.1.makeExpression())
                })
                ] as Document)
        }
    }
}

public enum Expression: ValueConvertible {
    case literal(ValueConvertible)
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        switch self {
        case .literal(let val):
            return val.makeBSONPrimitive()
        }
    }
}

public protocol ExpressionRepresentable {
    func makeExpression() -> Expression
}

extension String: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension Bool: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension ObjectId: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension Binary: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension Null: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension JavascriptCode: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension RegularExpression: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension Date: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension Double: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension Int: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension Int32: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension Int64: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

extension Document: ExpressionRepresentable {
    public func makeExpression() -> Expression {
        return .literal(self)
    }
}

public enum AccumulatedGroupExpression {
    case sum([ExpressionRepresentable])
    case average([ExpressionRepresentable])
    case max([ExpressionRepresentable])
    case min([ExpressionRepresentable])
    case first(ExpressionRepresentable)
    case last(ExpressionRepresentable)
    // TODO: Reimplement https://docs.mongodb.com/manual/reference/operator/aggregation/push/#grp._S_push
    case push(ExpressionRepresentable)
    case addToSet(ExpressionRepresentable)
    // TODO: Implement https://docs.mongodb.com/manual/reference/operator/aggregation/stdDevPop/#grp._S_stdDevPop
    // TODO: Implement https://docs.mongodb.com/manual/reference/operator/aggregation/stdDevSamp/#grp._S_stdDevSamp
    
    // MARK: Helpers
    
    public static func sumOf(_ expressions: ExpressionRepresentable...) -> AccumulatedGroupExpression {
        return .sum(expressions)
    }
    
    public static func sumOf(_ expressions: [ExpressionRepresentable]) -> AccumulatedGroupExpression {
        return .sum(expressions)
    }
    
    public static func averageOf(_ expressions: ExpressionRepresentable...) -> AccumulatedGroupExpression {
        return .average(expressions)
    }
    
    public static func averageOf(_ expressions: [ExpressionRepresentable]) -> AccumulatedGroupExpression {
        return .average(expressions)
    }
    
    public static func minOf(_ expressions: ExpressionRepresentable...) -> AccumulatedGroupExpression {
        return .min(expressions)
    }
    
    public static func minOf(_ expressions: [ExpressionRepresentable]) -> AccumulatedGroupExpression {
        return .min(expressions)
    }
    
    public static func maxOf(_ expressions: ExpressionRepresentable...) -> AccumulatedGroupExpression {
        return .max(expressions)
    }
    
    public static func maxOf(_ expressions: [ExpressionRepresentable]) -> AccumulatedGroupExpression {
        return .max(expressions)
    }
    
    // MARK: Converting
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        return makeDocument()
    }
    
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
