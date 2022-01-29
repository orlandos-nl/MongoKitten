import BSON

internal struct GetMore: Encodable, Sendable {
    /// This variable _must_ be the first encoded value, so keep it above all others
    /// The cursor id
    internal let getMore: Int64
    internal let collection: String
    internal var batchSize: Int?
    internal var maxTimeMS: Int32?
    internal var readConcern: ReadConcern?

    init(cursorId: Int64, batchSize: Int?, collection: String) {
        self.getMore = cursorId
        self.collection = collection
        self.batchSize = batchSize
    }
}

internal struct GetMoreReply: Decodable {
    struct CursorDetails: Codable {
        var id: Int64
        var ns: String
        var nextBatch: [Document]
    }

    internal let cursor: CursorDetails
    private let ok: Int
}
