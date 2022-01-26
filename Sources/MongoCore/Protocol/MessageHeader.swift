import BSON

public struct MongoMessageHeader: Sendable {
    public enum OpCode: Int32, Sendable {
        case reply = 1
        case update = 2001
        case insert = 2002
        // Reserved = 2003
        case query = 2004
        case getMore = 2005
        case delete = 2006
        case killCursors = 2007
        case message = 2013
    }
    
    public static let byteSize: Int32 = 16
    
    public let messageLength: Int32
    public var bodyLength: Int32 {
        return messageLength - MongoMessageHeader.byteSize
    }
    public var requestId: Int32
    public var responseTo: Int32
    public var opCode: OpCode
    
    internal init(messageLength: Int32, requestId: Int32, responseTo: Int32, opCode: OpCode) {
        self.messageLength = messageLength
        self.requestId = requestId
        self.responseTo = responseTo
        self.opCode = opCode
    }
    
    public init(bodyLength: Int32, requestId: Int32, responseTo: Int32, opCode: OpCode) {
        self.messageLength = MongoMessageHeader.byteSize + bodyLength
        self.requestId = requestId
        self.responseTo = responseTo
        self.opCode = opCode
    }
}
