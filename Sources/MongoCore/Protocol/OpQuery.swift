import NIO
import BSON

public struct OpQueryFlags: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    /// Tailable cursors are not closed when the last data is received.
    public static let tailableCursor = OpQueryFlags(rawValue: 1 << 1)
    
    /// This option allows querying a replica slave.
    public static let slaveOk = OpQueryFlags(rawValue: 1 << 2)
    
    /// Only for internal replication use
    // static let oplogReplay = Self(rawValue: 1 << 3)
    
    /// Normally cursors get closed after 10 minutes of inactivity. This option prevents that
    public static let noCursorTimeout = OpQueryFlags(rawValue: 1 << 4)
    
    /// To be used with TailableCursor. When at the end of the data, block for a while rather than returning no data.
    public static let awaitData = OpQueryFlags(rawValue: 1 << 5)
    
    /// Stream the data down into a full blast of 'more' packages
    static let exhaust = OpQueryFlags(rawValue: 1 << 6)
    
    //    static let partial = Self(rawValue: 1 << 7)
}

public struct OpQuery: MongoRequestMessage {
    public var header: MongoMessageHeader
    public var flags: OpQueryFlags
    public var fullCollectionName: String
    public var numberToSkip: Int32
    public var numberToReturn: Int32
    public var query: Document
    public var projection: Document?
    
    public init(
        header: MongoMessageHeader,
        flags: OpQueryFlags,
        fullCollectionName: String,
        numberToSkip: Int32,
        numberToReturn: Int32,
        query: Document,
        projection: Document?
    ) {
        self.header = header
        self.flags = flags
        self.fullCollectionName = fullCollectionName
        self.numberToSkip = numberToSkip
        self.numberToReturn = numberToReturn
        self.query = query
        self.projection = projection
    }
    
    public init(query: Document, requestId: Int32, fullCollectionName: String, flags: OpQueryFlags = []) {
        // TODO: Read query int32 header
        self.header = MongoMessageHeader(
            bodyLength: Int32(13 + fullCollectionName.utf8.count + query.makeByteBuffer().readableBytes),
            requestId: requestId,
            responseTo: 0,
            opCode: .query
        )
        self.flags = flags
        self.fullCollectionName = fullCollectionName
        self.numberToSkip = 0
        self.numberToReturn = 1
        self.query = query
        self.projection = nil
    }
    
    public init(reading buffer: inout ByteBuffer, header: MongoMessageHeader) throws {
        guard header.opCode == .query else {
            throw MongoProtocolParsingError(reason: .unsupportedOpCode)
        }
        
        let finalRead = buffer.readerIndex + Int(header.bodyLength)
        
        let flags = try buffer.assertLittleEndian() as UInt32
        let fullCollectionName = try buffer.readCString()
        let numberToSkip = try buffer.assertLittleEndian() as Int32
        let numberToReturn = try buffer.assertLittleEndian() as Int32
        
        let query = try buffer.assertReadDocument()
        let projection: Document?
        
        if finalRead == buffer.readerIndex {
            projection = nil
        } else {
            projection = try buffer.assertReadDocument()
        }
        
        self.init(
            header: header,
            flags: OpQueryFlags(rawValue: flags),
            fullCollectionName: fullCollectionName,
            numberToSkip: numberToSkip,
            numberToReturn: numberToReturn,
            query: query,
            projection: projection
        )
    }
    
    public func write(to out: inout ByteBuffer) {
        out.writeMongoHeader(header)
        out.writeInteger(flags.rawValue, endianness: .little)
        out.writeString(fullCollectionName)
        out.writeInteger(0x00 as UInt8)
        out.writeInteger(numberToSkip, endianness: .little)
        out.writeInteger(numberToReturn, endianness: .little)
        var buffer = query.makeByteBuffer()
        out.writeBuffer(&buffer)
        
        if var projection = self.projection?.makeByteBuffer() {
            out.writeBuffer(&projection)
        }
    }
}
