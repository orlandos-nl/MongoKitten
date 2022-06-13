import BSON
import MongoCore

public struct AggregateCommand: Encodable, Sendable {
    public let aggregate: String
    public var pipeline: [Document]
    public var explain: Bool?
    public var allowDiskUse: Bool?
    public var cursor = CursorSettings()
    public var comment: String?
    public var readConcern: ReadConcern?
    public var collation: Collation?
    public var hint: EitherPrimitive<String, Document>?
    
    /// Only available for `$out` operations
    public var bypassDocumentValidation: Bool?
    
    /// Only available for `$out` operations
    public var writeConcern: WriteConcern?
    
    public init(inCollection collection: String, pipeline: [Document]) {
        self.aggregate = collection
        self.pipeline = pipeline
    }
}
