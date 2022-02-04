import BSON

public struct MongoCursorResponse: Decodable, Sendable {
    public struct Cursor: Codable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case id, firstBatch
            case namespace = "ns"
        }
        
        public var id: Int64
        public var namespace: String
        public var firstBatch: [Document]
        
        public init(id: Int64, namespace: String, firstBatch: [Document]) {
            self.id = id
            self.namespace = namespace
            self.firstBatch = firstBatch
        }
    }
    
    public let cursor: Cursor
    public let ok: Int
}
