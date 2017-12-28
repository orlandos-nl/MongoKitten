import Async
import Bits
import Foundation

final class ServerReplyParser: Async.Stream, ConnectionContext {
    typealias Input = ByteBuffer
    typealias Output = ServerReply
    
    /// Downstream input stream accepting byte buffers
    private var downstream: AnyInputStream<ServerReply>?
    
    /// Upstream output stream outputting byte buffers
    private var upstream: ConnectionContext?
    
    /// Remaining output requested
    var remainingOutputRequested: UInt = 0
    
    var upstreamBuffer: ByteBuffer? {
        didSet {
            self.upstreamOffset = 0
        }
    }
    
    var upstreamOffset = 0
    
    var totalLength: Int?
    var requestId: Int32?
    var responseTo: Int32?
    var opCode: Int32?
    var flags: ReplyFlags?
    var cursorID: Int?
    var startingFrom: Int32?
    var numbersReturned: Int32?
    var documents = [Document]()
    var documentsData = Data()
    var documentsScanned: Int32 = 0
    var unconsumed = Data()
    
    var isComplete: Bool {
        return requestId != nil && responseTo != nil && flags != nil && cursorID != nil && startingFrom != nil && numbersReturned != nil && numericCast(documents.count) == numbersReturned
    }
    
    init() {
        // largest data (cursorID Int64) - 1 byte for not complete
        unconsumed.reserveCapacity(7)
    }
    
    func input(_ event: InputEvent<ByteBuffer>) {
        switch event {
        case .close: process()
        case .connect(let upstream):
            self.upstream = upstream
        case .error(let error): downstream?.error(error)
        case .next(let input):
            self.upstreamBuffer = input
            process()
        }
    }
    
    func output<S>(to inputStream: S) where S : Async.InputStream, ServerReplyParser.Output == S.Input {
        downstream = AnyInputStream(inputStream)
        inputStream.connect(to: self)
    }
    
    func connection(_ event: ConnectionEvent) {
        switch event {
        case .cancel:
            remainingOutputRequested = 0
            downstream?.close()
        case .request(let count):
            remainingOutputRequested += count
            
            if self.upstreamBuffer == nil {
                upstream?.request()
            }
            
            process()
        }
    }
    
    func process() {
        while true {
            guard let buffer = upstreamBuffer else {
                return
            }
            
            if upstreamOffset >= buffer.count {
                upstream?.request()
                return
            }
            
            self.process(
                consuming: buffer.baseAddress!.advanced(by: upstreamOffset),
                length: buffer.count - upstreamOffset
            )
        }
    }
    
    func process(consuming: BytesPointer, length: Int)  {
        var advanced = 0
        
        func require(_ n: Int) -> Bool {
            guard unconsumed.count &+ (length &- advanced) >= n else {
                advanced += min(n &- unconsumed.count, length)
                let data = Array(UnsafeBufferPointer(start: consuming.advanced(by: advanced), count: advanced))
                self.unconsumed.append(contentsOf: data)
                
                return false
            }
            
            return true
        }
        
        func makeInt32() -> Int32? {
            guard require(4) else {
                return nil
            }
            
            if unconsumed.count > 0 {
                var data = Data(repeating: 0, count: 4 - unconsumed.count)
                
                data.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer<UInt8>) in
                    _ = memcpy(pointer, consuming.advanced(by: advanced), 4 - unconsumed.count)
                }
                
                data = unconsumed + data
                
                advanced += 4 - unconsumed.count
                
                unconsumed.removeFirst(min(4, unconsumed.count))
                
                return Int32.make(data)
            } else {
                defer { advanced += 4 }
                return consuming.advanced(by: advanced).withMemoryRebound(to: Int32.self, capacity: 1, { $0.pointee })
            }
        }
        
        func makeInt64() -> Int64? {
            guard require(8) else {
                return nil
            }
            
            if unconsumed.count > 0 {
                var data = Data(repeating: 0, count: 8 - unconsumed.count)
                
                data.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer<UInt8>) in
                    _ = memcpy(pointer, consuming.advanced(by: advanced), 8 - unconsumed.count)
                }
                
                data = unconsumed + data
                
                advanced += 8 - unconsumed.count
                
                unconsumed.removeFirst(min(8, unconsumed.count))
                
                return Int64.make(data)
            } else {
                defer { advanced += 8 }
                return consuming.advanced(by: advanced).withMemoryRebound(to: Int64.self, capacity: 1, { $0.pointee })
            }
        }
        
        if totalLength == nil {
            guard let totalLength = makeInt32() else {
                upstreamOffset += advanced
                return
            }
            
            self.totalLength = Int(totalLength) as Int
        }
        
        if requestId == nil {
            guard let requestId = makeInt32() else {
                upstreamOffset += advanced
                return
            }
            
            self.requestId = requestId
        }
        
        if responseTo == nil {
            guard let responseTo = makeInt32() else {
                upstreamOffset += advanced
                return
            }
            
            self.responseTo = responseTo
        }
        
        if opCode == nil {
            guard let opCode = makeInt32() else {
                upstreamOffset += advanced
                return
            }
            
            self.opCode = opCode
        }
        
        if flags == nil {
            guard let flag = makeInt32() else {
                upstreamOffset += advanced
                return
            }
            
            self.flags = ReplyFlags(rawValue: flag)
        }
        
        if cursorID == nil {
            guard let cursorID = makeInt64() else {
                upstreamOffset += advanced
                return
            }
            
            self.cursorID = Int(cursorID)
        }
        
        if startingFrom == nil {
            guard let startingFrom = makeInt32() else {
                upstreamOffset += advanced
                return
            }
            
            self.startingFrom = startingFrom
        }
        
        if numbersReturned == nil {
            guard let numbersReturned = makeInt32() else {
                upstreamOffset += advanced
                return
            }
            
            self.numbersReturned = numbersReturned
        }
        
        advanced += scanDocuments(from: consuming.advanced(by: advanced), length: length - advanced)
        upstreamOffset += advanced
        
        if isComplete, let reply = construct() {
            downstream?.next(reply)
        }
        
        return
    }
    
    func scanDocuments(from pointer: BytesPointer, length: Int) -> Int {
        guard let numbersReturned = numbersReturned else {
            return 0
        }
        
        var advanced = 0
        
        while documentsScanned < numbersReturned, advanced < length {
            let documentSize: Int = pointer.advanced(by: advanced).withMemoryRebound(to: Int32.self, capacity: 1) { numericCast($0.pointee) }
            
            let remaining = length - advanced
            
            if documentSize <= remaining {
                documentsData.append(pointer, count: documentSize)
                advanced += documentSize
                
                documents.append(Document(data: documentsData))
                
                documentsData = Data()
            } else {
                documentsData.append(pointer, count: remaining)
                advanced += remaining
            }
        }
        
        return advanced
    }
    
    func construct() -> ServerReply? {
        guard
            let requestId = requestId,
            let responseTo = responseTo,
            let flags = flags,
            let cursorID = cursorID,
            let startingFrom = startingFrom,
            let numbersReturned = numbersReturned
        else {
            return nil
        }
        
        let docs = self.documents
        
        self.totalLength = nil
        self.requestId = nil
        self.responseTo = nil
        self.opCode = nil
        self.flags = nil
        self.cursorID = nil
        self.startingFrom = nil
        self.numbersReturned = nil
        self.documentsScanned = 0
        self.documents = []
        self.documentsData = Data()
        
        return ServerReply(requestID: requestId, responseTo: responseTo, flags: flags, cursorID: cursorID, startingFrom: startingFrom, numbersReturned: numbersReturned, documents: docs)
    }
}

public struct ServerReply {
    let requestID: Int32
    let responseTo: Int32
    let flags: ReplyFlags
    let cursorID: Int
    let startingFrom: Int32
    let numbersReturned: Int32
    var documents: [Document]
}
