import BSON
import NIO

public struct Insert<C: Codable>: MongoDBCommand {
    public typealias Result = InsertReply
    
    var collectionReference: CollectionReference {
        return insert
    }
    
    public let insert: CollectionReference
    public var documents: [C]
    public var ordered: Bool?
    public var bypassDocumentValidation: Bool?
    
    static var writing: Bool {
        return true
    }
    
    static var emitsCursor: Bool {
        return false
    }
    
    public init(_ documents: [C], into collection: CollectionReference) {
        self.insert = collection
        self.documents = Array(documents)
    }
    
    public func execute(on database: MongoDBConnection) throws -> EventLoopFuture<Insert<C>.Result> {
        return database.execute(command: self)
    }
}

public struct InsertReply: ServerReplyDecodable {
    public var n: Int?
    public var ok: Int
    public var errmsg: String?
//    public var writeErrors: [Errors.Write]?
//    public var writeConcernError: [Errors.WriteConcern]?
}
