import BSON

public struct GetMore: Codable, Sendable {
    /// This variable _must_ be the first encoded value, so keep it above all others
    /// The cursor id
    public let getMore: Int64
    public let collection: String
    public var batchSize: Int?
    public var maxTimeMS: Int32?
    public var readConcern: ReadConcern?

    init(cursorId: Int64, batchSize: Int?, collection: String) {
        self.getMore = cursorId
        self.collection = collection
        self.batchSize = batchSize
    }
}

public struct GetMoreReply: Codable, Sendable {
    public struct CursorDetails: Codable, Sendable {
        public var id: Int64
        public var ns: String
        public var nextBatch: [Document]
    }

    public let cursor: CursorDetails
    private let ok: Int
}
