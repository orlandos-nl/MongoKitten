import Async
import Bits
import Foundation

final class ServerReplyParser: Async.Stream {
    func close() {
        stream.close()
    }
    
    func onClose(_ onClose: ClosableStream) {
        stream.onClose(onClose)
    }
    
    typealias Input = ByteBuffer
    typealias Output = ServerReply
    
    func onOutput<I>(_ input: I) where I : Async.InputStream, ServerReplyParser.Output == I.Input {
        stream.onOutput(input)
    }
    
    func onError(_ error: Error) {
        stream.onError(error)
    }
    
    let stream = BasicStream<Output>()
    
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
    
    func onInput(_ input: ByteBuffer) {
        guard let base = input.baseAddress else {
            return
        }
        
        var advanced = 0
        
        repeat {
            advanced += self.process(consuming: base.advanced(by: advanced), withLengthOf: input.count - advanced)
        } while advanced < input.count
    }
    
    func process(consuming: UnsafePointer<UInt8>, withLengthOf length: Int) -> Int {
        var advanced = 0
        var length = length
        
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
                return advanced
            }
            
            self.totalLength = Int(totalLength) as Int
        }
        
        if requestId == nil {
            guard let requestId = makeInt32() else {
                return advanced
            }
            
            self.requestId = requestId
        }
        
        if responseTo == nil {
            guard let responseTo = makeInt32() else {
                return advanced
            }
            
            self.responseTo = responseTo
        }
        
        if opCode == nil {
            guard let opCode = makeInt32() else {
                return advanced
            }
            
            self.opCode = opCode
        }
        
        if flags == nil {
            guard let flag = makeInt32() else {
                return advanced
            }
            
            self.flags = ReplyFlags(rawValue: flag)
        }
        
        if cursorID == nil {
            guard let cursorID = makeInt64() else {
                return advanced
            }
            
            self.cursorID = Int(cursorID)
        }
        
        if startingFrom == nil {
            guard let startingFrom = makeInt32() else {
                return advanced
            }
            
            self.startingFrom = startingFrom
        }
        
        if numbersReturned == nil {
            guard let numbersReturned = makeInt32() else {
                return advanced
            }
            
            self.numbersReturned = numbersReturned
        }
        
        advanced += scanDocuments(from: consuming.advanced(by: advanced), length: length - advanced)
        
        if isComplete, let reply = construct() {
            stream.onInput(reply)
        }
        
        return advanced
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
