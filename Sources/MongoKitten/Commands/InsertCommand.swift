import BSON
import NIO

public struct InsertCommand: WriteCommand {
    typealias Reply = InsertReply
    
    internal var namespace: Namespace {
        return insert
    }
    
    internal let insert: Namespace
    public var documents: [Document]
    public var ordered: Bool?
    public var bypassDocumentValidation: Bool?
    public var writeConcern: WriteConcern?
    
    static var writing: Bool {
        return true
    }
    
    static var emitsCursor: Bool {
        return false
    }
    
    public init(_ documents: [Document], into collection: Collection) {
        self.insert = collection.namespace
        self.documents = Array(documents)
    }
}

public struct InsertReply: ServerReplyDecodableResult {
    typealias Result = InsertReply
    
    private enum CodingKeys: String, CodingKey {
        case successfulInserts = "n"
        case ok
        case errorMessage = "errmsg"
    }
    
    public let successfulInserts: Int?
    private let ok: Int
    public private(set) var errorMessage: String?
    
    public var isSuccessful: Bool {
        return ok == 1
    }
    
    func makeResult(on collection: Collection) -> InsertReply {
        return self
    }
}
