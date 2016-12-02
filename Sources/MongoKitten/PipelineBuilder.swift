import Foundation
import BSON

public class PipelineDocument: PipelineWithInput, FinalizedPipeline {
    public var pipelineDocument: Document = []
    
    public var pipeline: Document {
        return pipelineDocument
    }
    
    public func makePipelineWithInput() -> PipelineWithInput {
        return self
    }
    
    public func finalize() -> FinalizedPipeline {
        return self
    }
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        return pipelineDocument
    }
    
    public static func make() -> Pipeline {
        return PipelineDocument()
    }
    
    public init() { }
}

public protocol FinalizedPipeline: ValueConvertible {
    var pipeline: Document { get }
}

public protocol Pipeline: class, ValueConvertible {
    var pipelineDocument: Document { get set }
    func makePipelineWithInput() -> PipelineWithInput
    func finalize() -> FinalizedPipeline
}

public protocol PipelineWithInput: Pipeline {
    
}

extension Pipeline {
    @discardableResult
    public func project(_ projection: Projection) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$project": projection
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func match(_ query: Query) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$match": query
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func match(_ query: Document) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$match": query
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func sample(sizeOf size: Int) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$sample": ["size": size] as Document
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func skip(_ skip: Int) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$skip": skip
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func limit(_ limit: Int) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$limit": limit
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func sort(_ sort: Sort) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$sort": sort
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func group(groupDocument: Document) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$group": groupDocument
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func group(computedFields: [String: AccumulatedGroupExpression] = [:], id: ExpressionRepresentable) -> PipelineWithInput {
        let groupDocument = computedFields.reduce([:] as Document) { (doc, expressionPair) -> Document in
            guard expressionPair.key != "_id" else {
                return doc
            }
            
            var doc = doc
            
            doc[expressionPair.key] = expressionPair.value.makeDocument()
            
            doc[raw: "_id"] = id.makeExpression()
            
            return doc
        }
        
        self.pipelineDocument.append([
            "$group": groupDocument
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func unwind(atPath path: String, includeArrayIndex: String? = nil, preserveNullAndEmptyArrays: Bool? = nil) -> PipelineWithInput {
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
        
        self.pipelineDocument.append([
            "$unwind": unwind
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func lookup(fromCollection from: String, localField: String, foreignField: String, as: String) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$lookup": [
                "from": from,
                "localField": localField,
                "foreignField": foreignField,
                "as": `as`
                ] as Document
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func lookup(fromCollection from: Collection, localField: String, foreignField: String, as: String) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$lookup": [
                    "from": from.name,
                    "localField": localField,
                    "foreignField": foreignField,
                    "as": `as`
                ] as Document
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func out(toCollection collection: Collection) -> FinalizedPipeline {
        return out(toCollectionNamed: collection.name)
    }
    
    @discardableResult
    public func writeOutput(toCollection collection: Collection) -> FinalizedPipeline {
        return self.writeOutput(toCollectionNamed: collection.name)
    }
    
    @discardableResult
    public func out(toCollectionNamed collectionName: String) -> FinalizedPipeline {
        return self.writeOutput(toCollectionNamed: collectionName)
    }
    
    @discardableResult
    public func writeOutput(toCollectionNamed collectionName: String) -> FinalizedPipeline {
        self.pipelineDocument.append([
                "$out": collectionName
            ] as Document)
        
        return self.finalize()
    }
    
    @discardableResult
    public func facet(_ facet: [(String, PipelineWithInput)]) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$facet": Document(dictionaryElements: facet.map {
                ($0.0, $0.1)
            })
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func count(insertedAtKey key: String) -> PipelineWithInput {
        self.pipelineDocument.append([
            "$count": key
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func replaceRoot(with expression: ExpressionRepresentable) -> PipelineWithInput {
        self.pipelineDocument.append([
                "$replaceRoot": [
                    "newRoot": expression.makeExpression()
                ] as Document
            ] as Document)
        
        return self.makePipelineWithInput()
    }
    
    @discardableResult
    public func addFields(_ fields: [String: ExpressionRepresentable]) -> PipelineWithInput {
        self.pipelineDocument.append([
                "$addFields": Document(dictionaryElements: fields.map {
                    ($0.0, $0.1.makeExpression())
                })
            ] as Document)
        
        return self.makePipelineWithInput()
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

public enum AccumulatedGroupExpression: DocumentRepresentable {
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
