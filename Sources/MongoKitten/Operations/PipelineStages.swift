public protocol PipelineStage: Encodable {
    associatedtype Output
    
    func readOutput(from cursor: Cursor<Document>) throws -> Output
}

extension PipelineStage where Output == Cursor<Document> {
    public func readOutput(from cursor: Cursor<Document>) throws -> Output {
        return cursor
    }
}

public struct Pipeline<Output> {
    typealias Transform = (Cursor<Document>) throws -> Output
    
    public var stages: [Document]
    internal var transform: Transform
    
    fileprivate init(stages: [Document], transform: @escaping Transform) {
        self.stages = stages
        self.transform = transform
    }
    
    public func adding<Stage: PipelineStage>(
        stage: Stage
    ) throws -> Pipeline<Stage.Output> {
        let newStage = try BSONEncoder().encode(stage)
        return Pipeline<Stage.Output>(
            stages: self.stages + [newStage],
            transform: stage.readOutput
        )
    }
}

extension Pipeline where Output == Cursor<Document> {
    public init() {
        self.init(stages: []) { $0 }
    }
}

public struct MatchStage: PipelineStage {
    public typealias Output = Cursor<Document>
    
    public enum CodingKeys: String, CodingKey {
        case query = "$match"
    }
    
    public var query: Query
}

extension Pipeline where Output == Cursor<Document> {
    public func match(_ query: Query) throws -> Pipeline<Cursor<Document>> {
        return try self.adding(stage: MatchStage(query: query))
    }
    
    public func count(writingInto outputField: String) throws -> Pipeline<Int> {
        return try self.adding(stage: CountStage(writingInto: outputField))
    }
}

//public struct ProjectStage: TypeSafePipelineStage {
//    public typealias Output = [Document]
//
//    public enum CodingKeys: String, CodingKey {
//        case projection = "$project"
//    }
//
//    var projection: Projection
//}
//
//public struct AddFieldsStage: TypeSafePipelineStage {
//    public typealias Output = [Document]
//
//    public enum CodingKeys: String, CodingKey {
//        case projection = "$addFields"
//    }
//
//    public var newFields: Projection
//}

public struct CountStage: PipelineStage {
    public typealias Output = Int
    
    public enum CodingKeys: String, CodingKey {
        case outputField = "$count"
    }
    
    public var outputField: String
    
    public init(writingInto outputField: String) {
        self.outputField = outputField
    }
    
    public func readOutput(from cursor: Cursor<Document>) throws -> Int {
        let doc = try cursor.singleDocument()
        
        switch doc[outputField] {
        case let int as Int32:
            return numericCast(int)
        case let int as Int64:
            return numericCast(int)
        default:
            throw MongoKittenError(.unexpectedAggregateResults, reason: .unexpectedValue)
        }
    }
}

internal extension Cursor where Element == Document {
    func singleDocument() throws -> Document {
        guard self.drained && self.buffer.count == 1 else {
            let reason: MongoKittenError.Reason
            
            if self.buffer.count == 0 {
                reason = .noResultDocuments
            } else {
                reason = .multipleResultDocuments
            }
            
            throw MongoKittenError(.unexpectedAggregateResults, reason: reason)
        }
        
        return self.buffer[0]
    }
}
