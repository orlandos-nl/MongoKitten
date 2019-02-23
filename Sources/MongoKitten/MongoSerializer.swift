import BSON
import NIO

/// A type capable of serializing queries to MongoDB into a NIO ByteBuffer
class MongoSerializer {
    var supportsOpMessage = false
    var slaveOk = false
    var includeSession = false
    let supportsQueryCommand = true
    
    /// Encode a command specifically as OPMessage wire protocol message
    func encodeOpMessage(data: MongoDBCommandContext, into out: inout ByteBuffer) throws {
        let opCode = MessageHeader.OpCode.message
        
        let encoder = BSONEncoder()
        
        var document = try encoder.encode(data.command)
        document["$db"] = data.command.namespace.databaseName
        
        if includeSession, let session = data.session {
            document["lsid"]["id"] = session.sessionId.id
        }
        
        if let transaction = data.transaction {
            document["txnNumber"] = transaction.id
            document["autocommit"] = transaction.autocommit
            
            if transaction.startTransaction {
                document["startTransaction"] = true
            }
        }
        
        let flags: OpMsgFlags = []
        
        var buffer = document.makeByteBuffer()
        
        // MongoDB supports messages up to 16MB
        if buffer.writerIndex > 16_000_000 {
            data.promise.fail(error: MongoKittenError(.commandFailure, reason: MongoKittenError.Reason.commandSizeTooLarge))
            return
        }
        
        let header = MessageHeader(
            messageLength: MessageHeader.byteSize + 4 + 1 + Int32(buffer.readableBytes),
            requestId: data.requestID,
            responseTo: 0,
            opCode: opCode
        )
        
        out.write(header)
        out.write(integer: flags.rawValue, endianness: .little)
        out.write(integer: 0 as UInt8, endianness: .little) // section kind 0
        
        out.write(buffer: &buffer)
    }
    
    /// Encode a command specifically as OPQuery wire protocol message
    func encodeQueryCommand(data: MongoDBCommandContext, into out: inout ByteBuffer) throws {
        let opCode = MessageHeader.OpCode.query
        
        let encoder = BSONEncoder()
        
        var document = try encoder.encode(data.command)
        
        if includeSession, let session = data.session {
            document["lsid"]["id"] = session.sessionId.id
        }
        
        var flags: OpQueryFlags = []
        
        if slaveOk {
            flags.insert(.slaveOk)
        }
        
        var buffer = document.makeByteBuffer()
        
        // MongoDB supports messages up to 16MB
        if buffer.writerIndex > 16_000_000 {
            data.promise.fail(error: MongoKittenError(.commandFailure, reason: MongoKittenError.Reason.commandSizeTooLarge))
            return
        }
        
        let namespace = data.command.namespace.databaseName + ".$cmd"
        let namespaceSize = Int32(namespace.utf8.count) + 1
        
        let header = MessageHeader(
            messageLength: MessageHeader.byteSize + namespaceSize + 12 + Int32(buffer.readableBytes),
            requestId: data.requestID,
            responseTo: 0,
            opCode: opCode
        )
        
        out.write(header)
        out.write(integer: flags.rawValue, endianness: .little)
        out.write(string: namespace)
        out.write(integer: 0 as UInt8) // null terminator for String
        out.write(integer: 0 as Int32, endianness: .little) // Skip handled by query
        out.write(integer: 1 as Int32, endianness: .little) // Number to return
        
        out.write(buffer: &buffer)
    }
    
    /// Encodes the message dependent on the settings of this serializer.
    /// Which can be determined via the connection handshake
    func encode(data: MongoDBCommandContext, into out: inout ByteBuffer) throws {
        if supportsOpMessage {
            try encodeOpMessage(data: data, into: &out)
        } else if supportsQueryCommand {
            try encodeQueryCommand(data: data, into: &out)
        } else {
            throw MongoKittenError(.unsupportedProtocol, reason: nil)
        }
    }
}

extension ByteBuffer {
    mutating func write(_ header: MessageHeader) {
        write(integer: header.messageLength, endianness: .little)
        write(integer: header.requestId, endianness: .little)
        write(integer: header.responseTo, endianness: .little)
        write(integer: header.opCode.rawValue, endianness: .little)
    }
}
