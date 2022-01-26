import NIO
import BSON

public struct OpReplyFlags: OptionSet, Sendable {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    /// A GET_MORE was sent with an invalid cursorID, possibly because the cursor expired
    public static let cursorNotFound = OpReplyFlags(rawValue: 1 << 0)
    
    /// Need I say more? The query failed.
    public static let queryFailure = OpReplyFlags(rawValue: 1 << 1)
    
    /// MongoS only
    //    public static let shardConfigStale = Self(rawValue: 1 << 1)
    
    /// The server supports the awaitData options
    public static let awaitCapable = OpReplyFlags(rawValue: 1 << 3)
    
    // The rest is reserved (will likely be left unused)
}

public struct OpReply: MongoResponseMessage, Sendable {
    public var header: MongoMessageHeader
    public var cursorId: Int64
    public var documents: [Document]
    public var startingFrom: Int32
    public var numberReturned: Int32
    public var flags: OpReplyFlags
    
    public init(
        header: MongoMessageHeader,
        cursorId: Int64,
        documents: [Document],
        startingFrom: Int32,
        numberReturned: Int32,
        flags: OpReplyFlags
    ) {
        self.header = header
        self.cursorId = cursorId
        self.documents = documents
        self.startingFrom = startingFrom
        self.numberReturned = numberReturned
        self.flags = flags
    }
    
    public init(documents: [Document], cursorId: Int64 = 0, responseTo: Int32, flags: OpReplyFlags = []) {
        // TODO: Read query int32 header
        self.header = MongoMessageHeader(
            bodyLength: Int32(20 + documents.binarySize),
            requestId: 0,
            responseTo: responseTo,
            opCode: .reply
        )
        self.flags = flags
        self.cursorId = cursorId
        self.documents = documents
        self.startingFrom = 0
        self.numberReturned = Int32(documents.count)
    }
    
    public init(reading buffer: inout ByteBuffer, header: MongoMessageHeader) throws {
        guard header.opCode == .reply else {
            throw MongoProtocolParsingError(reason: .unsupportedOpCode)
        }
        
        let flags = try buffer.assertLittleEndian() as UInt32
        let cursorId = try buffer.assertLittleEndian() as Int64
        let startingFrom = try buffer.assertLittleEndian() as Int32
        let numberReturned = try buffer.assertLittleEndian() as Int32
        let documents = try [Document](buffer: &buffer, count: numericCast(numberReturned))
        
        self.init(
            header: header,
            cursorId: cursorId,
            documents: documents,
            startingFrom: startingFrom,
            numberReturned: numberReturned,
            flags: OpReplyFlags(rawValue: flags)
        )
    }
    
    public func write(to out: inout ByteBuffer) {
        out.writeMongoHeader(header)
        out.writeInteger(flags.rawValue, endianness: .little)
        out.writeInteger(cursorId, endianness: .little)
        out.writeInteger(startingFrom, endianness: .little)
        out.writeInteger(numberReturned, endianness: .little)
        
        for document in documents {
            var buffer = document.makeByteBuffer()
            out.writeBuffer(&buffer)
        }
    }
}
