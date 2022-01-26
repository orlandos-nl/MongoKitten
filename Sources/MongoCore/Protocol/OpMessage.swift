import NIO
import BSON

fileprivate let knownBits: UInt32 = 0b11000000_00000001_00000000_00000000
fileprivate let unknownBits: UInt32 = knownBits ^ .max

public struct OpMessageFlags: OptionSet, Sendable {
    public var rawValue: UInt32
    
    /// [See spec](https://docs.mongodb.com/manual/reference/mongodb-wire-protocol/#flag-bits)
    public var isValid: Bool {
        return rawValue & unknownBits == 0
    }
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    /// The message ends with 4 bytes containing a CRC-32C [1] checksum. See Checksum for details.
    public static let checksumPresent = OpMessageFlags(rawValue: 1 << 0)
    
    /// Another message will follow this one without further action from the receiver. The receiver MUST NOT send another message until receiving one with moreToCome set to 0 as sends may block, causing deadlock. Requests with the moreToCome bit set will not receive a reply. Replies will only have this set in response to requests with the exhaustAllowed bit set.
    public static let moreToCome = OpMessageFlags(rawValue: 1 << 1)
    
    /// The client is prepared for multiple replies to this request using the moreToCome bit. The server will never produce replies with the moreToCome bit set unless the request has this bit set.
    ///
    /// This ensures that multiple replies are only sent when the network layer of the requester is prepared for them. MongoDB 3.6 ignores this flag.
    public static let exhaustAllowed = OpMessageFlags(rawValue: 1 << 16)
}


public struct OpMessage: MongoRequestMessage, MongoResponseMessage , Sendable{
    public enum SectionType: Int32, Sendable {
        case body = 0
        case sequence = 1
    }
    
    public struct Sequence: Sendable {
        public var size: Int32
        public var sequenceIdentifier: String
        public var documents: [Document]
        
        public init(size: Int32, sequenceIdentifier: String, documents: [Document]) {
            // TODO: Read BSON int32 header
            assert(size == 4 + sequenceIdentifier.utf8.count + 1 + documents.reduce(0) { $0 + $1.makeByteBuffer().readableBytes })
            
            self.size = size
            self.sequenceIdentifier = sequenceIdentifier
            self.documents = documents
        }
    }
    
    public enum Section: Sendable {
        case body(Document)
        case sequence(Sequence)
    }
    
    public var header: MongoMessageHeader
    public var flags: OpMessageFlags
    public var sections: [Section]
    public var checksum: UInt32?
    
    public init(header: MongoMessageHeader, flags: OpMessageFlags, sections: [Section], checksum: UInt32?) {
        assert((checksum != nil) == flags.contains(.checksumPresent))
        assert(header.bodyLength == 4 + sections.binarySize + (checksum == nil ? 0 : 4))
        
        self.header = header
        self.flags = flags
        self.sections = sections
        self.checksum = checksum
        
        assert((try? checkChecksum()) != nil)
    }
    
    public init(sections: [Section], requestId: Int32, flags: OpMessageFlags = []) {
        // TODO: Stop ignoring `checksum`
        assert(!flags.contains(.checksumPresent), "Checksums are not yet supported")
        
        self.flags = flags
        self.sections = sections
        
        // TODO: Checksum influences the body length
        self.header = MongoMessageHeader(bodyLength: Int32(4 + sections.binarySize), requestId: requestId, responseTo: 0, opCode: .message)
        self.checksum = nil
    }
    
    public init(sections: [Section], responseTo: Int32, flags: OpMessageFlags = []) {
        // TODO: Stop ignoring `checksum`
        assert(!flags.contains(.checksumPresent), "Checksums are not yet supported")
        
        self.flags = flags
        self.sections = sections
        
        // TODO: Checksum influences the body length
        self.header = MongoMessageHeader(bodyLength: Int32(4 + sections.binarySize), requestId: 0, responseTo: responseTo, opCode: .message)
        self.checksum = nil
    }
    
    public init(body: Document, requestId: Int32, flags: OpMessageFlags = []) {
        self.init(sections: [.body(body)], requestId: requestId, flags: flags)
    }
    
    public init(body: Document, responseTo: Int32, flags: OpMessageFlags = []) {
        self.init(sections: [.body(body)], responseTo: responseTo, flags: flags)
    }
    
    func checkChecksum() throws {
        // TODO: Check
    }
    
    public init(reading buffer: inout ByteBuffer, header: MongoMessageHeader) throws {
        guard header.opCode == .message else {
            throw MongoProtocolParsingError(reason: .unsupportedOpCode)
        }
        
        // Read flags
        // TODO: The first 16 bits (0-15) are required and parsers MUST error if an unknown bit is set.
        let rawFlags = try buffer.assertLittleEndian() as UInt32
        let flags = OpMessageFlags(rawValue: rawFlags)
        
        var sections = [Section]()
        
        var sectionsSize = Int(header.bodyLength - 4)
        if flags.contains(.checksumPresent) {
            sectionsSize -= 4
        }
        let endReaderIndex = buffer.readerIndex + sectionsSize
        
        // minimum BSON size is 5, checksum is 4 bytes, so this works
        while buffer.readableBytes > 0, buffer.readerIndex < endReaderIndex {
            let kind = try buffer.assertLittleEndian() as UInt8
            switch kind {
            case 0: // body
                try sections.append(.body(buffer.assertReadDocument()))
            case 1: // document sequence
                let size = try buffer.assertLittleEndian() as Int32
                let documentSequenceIdentifier = try buffer.readCString() // Document sequence identifier
                // TODO: Handle document sequence identifier correctly
                
                let bsonObjectsSectionSize = Int(size) - 4 - documentSequenceIdentifier.utf8.count - 1
                
                let documents = try [Document](buffer: &buffer, consumeBytes: bsonObjectsSectionSize)
                let sequence = OpMessage.Sequence(
                    size: size,
                    sequenceIdentifier: documentSequenceIdentifier,
                    documents: documents
                )
                sections.append(.sequence(sequence))
            default:
                throw MongoProtocolParsingError(reason: .unexpectedValue)
            }
        }
        
        let checksum: UInt32?
        
        if flags.contains(.checksumPresent) {
            // Checksum validation is unimplemented
            // MongoDB 3.6 does not support validating the message checksum, but will correctly skip it if present.
            checksum = buffer.readInteger(endianness: .little, as: UInt32.self)
        } else {
            checksum = nil
        }
        
        self.header = header
        self.checksum = checksum
        self.flags = flags
        self.sections = sections
        try checkChecksum()
    }
    
    public func write(to out: inout ByteBuffer) {
        out.writeMongoHeader(header)
        out.writeInteger(flags.rawValue, endianness: .little)
        
        for section in sections {
            switch section {
            case .body(let document):
                out.writeInteger(0 as UInt8)
                
                var buffer = document.makeByteBuffer()
                out.writeBuffer(&buffer)
            case .sequence(let sequence):
                out.writeInteger(1 as UInt8)
                out.writeInteger(sequence.size, endianness: .little)
                out.writeString(sequence.sequenceIdentifier)
                out.writeInteger(0x00 as UInt8)
                
                for document in sequence.documents {
                    var buffer = document.makeByteBuffer()
                    out.writeBuffer(&buffer)
                }
            }
        }
        
        if let checksum = checksum {
            out.writeInteger(checksum, endianness: .little)
        }
    }
}

extension Array where Element == OpMessage.Section {
    var binarySize: Int {
        return self.reduce(0) { base, section in
            let size: Int
            switch section {
            // TODO: Read BSON int32 header
            case .body(let document):
                 size = base + 1 + document.makeByteBuffer().readableBytes
            case .sequence(let sequence):
                // TODO: Read BSON int32 header
                size =  4 + sequence.sequenceIdentifier.utf8.count + 1 + sequence.documents.binarySize
                assert(size == sequence.size)
            }
            
            // A single document may not exceed this size
            assert(size <= 16_777_216, "BSON Object has an illegal size")
            return base + size
        }
    }
}

extension Array where Element == Document {
    var binarySize: Int {
        return reduce(0) { $0 + $1.makeByteBuffer().readableBytes }
    }
}
