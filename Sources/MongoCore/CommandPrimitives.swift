public struct MongoWriteError: Codable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case index, code
        case message = "errmsg"
    }
    
    public let index: Int
    public let code: Int
    public let message: String
    
    public init(index: Int, code: Int, message: String) {
        self.index = index
        self.code = code
        self.message = message
    }
}

public struct WriteConcernError: Codable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case code
        case message = "errmsg"
    }
    
    public let code: Int
    public let message: String
    
    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}
