import Async
import Bits
import Foundation

final class ServerReplyParser: Async.Stream {
    var outputStream: OutputHandler?
    var errorStream: BaseStream.ErrorHandler?
    
    typealias Input = ByteBuffer
    typealias Output = ServerReply
    
    var totalLength: Int?
    var requestId: Int32?
    var responseTo: Int32?
    var opCode: Int32?
    var flags: ReplyFlags?
    var cursorID: Int?
    var startingFrom: Int32?
    var numbersReturned: Int32?
    var documentsData = Data()
    var unconsumed = Data()
    var documentsComplete = false
    
    var isComplete: Bool {
        guard let totalLength = totalLength else {
            return false
        }
        
        return requestId != nil && responseTo != nil && flags != nil && cursorID != nil && startingFrom != nil && numbersReturned != nil && documentsComplete && totalLength - 36 == documentsData.count
    }
    
    init() {
        // largest data (cursorID Int64) - 1 byte for not complete
        unconsumed.reserveCapacity(7)
    }
    
    func inputStream(_ input: UnsafeBufferPointer<UInt8>) {
        guard let base = input.baseAddress else {
            return
        }
        
        self.process(consuming: base, withLengthOf: input.count)
    }
    
    func process(consuming: UnsafePointer<UInt8>, withLengthOf length: Int) {
        var advanced = 0
        var consuming = consuming
        var length = length
        
        func require(_ n: Int) -> Bool {
            guard unconsumed.count &+ (length &- advanced) >= n else {
                advanced = min(n &- unconsumed.count, length)
                let data = Array(UnsafeBufferPointer(start: consuming.advanced(by: advanced), count: advanced))
                self.unconsumed.append(contentsOf: data)
                consuming = consuming.advanced(by: advanced)
                
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
                
                advanced = 4 - unconsumed.count
                
                unconsumed.removeFirst(min(4, unconsumed.count))
                
                return Int32.make(data)
            } else {
                advanced = 4
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
                
                advanced = 8 - unconsumed.count
                
                unconsumed.removeFirst(min(8, unconsumed.count))
                
                return Int64.make(data)
            } else {
                advanced = 8
                return consuming.advanced(by: advanced).withMemoryRebound(to: Int64.self, capacity: 1, { $0.pointee })
            }
        }
        
        if totalLength == nil {
            guard let totalLength = makeInt32() else {
                return
            }
            
            self.totalLength = Int(totalLength) as Int
        }
        
        if requestId == nil {
            guard let requestId = makeInt32() else {
                return
            }
            
            self.requestId = requestId
        }
        
        if responseTo == nil {
            guard let responseTo = makeInt32() else {
                return
            }
            
            self.responseTo = responseTo
        }
        
        if opCode == nil {
            guard let opCode = makeInt32() else {
                return
            }
            
            self.opCode = opCode
        }
        
        if flags == nil {
            guard let flag = makeInt32() else {
                return
            }
            
            self.flags = ReplyFlags(rawValue: flag)
        }
        
        if cursorID == nil {
            guard let cursorID = makeInt64() else {
                return
            }
            
            self.cursorID = Int(cursorID)
        }
        
        if startingFrom == nil {
            guard let startingFrom = makeInt32() else {
                return
            }
            
            self.startingFrom = startingFrom
        }
        
        if numbersReturned == nil {
            guard let numbersReturned = makeInt32() else {
                return
            }
            
            self.numbersReturned = numbersReturned
        }
        
        guard let totalLength = totalLength, let numbersReturned = numbersReturned else {
            return
        }
        
        func checkDocuments() -> (count: Int, half: Int) {
            guard documentsData.count > 3 else {
                return (0, documentsData.count)
            }
            
            var count = 0
            var pos = 0
            
            while pos < documentsData.count {
                guard pos + 4 < documentsData.count else {
                    return (count, documentsData.count - pos)
                }
                
                let length = Int(Int32.make(documentsData[pos..<pos + 4]))
                
                guard pos + length <= documentsData.count else {
                    return (count, documentsData.count - pos)
                }
                
                pos += length
                count += 1
            }
            
            return (count, documentsData.count - pos)
        }
        
        @discardableResult
        func checkComplete(documentCount count: Int? = nil) -> Bool {
            let documentCount: Int
            
            if let count = count {
                documentCount = count
            } else {
                let (count, _) = checkDocuments()
                
                documentCount = count
            }
            
            if totalLength - 36 == documentsData.count, Int(numbersReturned) == documentCount {
                self.documentsComplete = true
                return true
            }
            
            return false
        }
        
        let (documentCount, halfComplete) = checkDocuments()
        
        if checkComplete(documentCount: documentCount) {
            return
        }
        
        if halfComplete > 0 {
            let startOfDocument = documentsData.endIndex.advanced(by: -halfComplete)
            
            let documentLength = Int(Int32.make(documentsData[startOfDocument..<startOfDocument.advanced(by: 4)]))
            let neededLength = documentLength - halfComplete
            
            advanced = min(length, neededLength)
            
            documentsData.append(contentsOf: UnsafeBufferPointer<Byte>(start: consuming, count: advanced))
            
            guard length > neededLength else {
                checkComplete()
                
                return
            }
        } else {
            let unconsumedCopy = unconsumed
            
            guard let documentLength = Int(makeInt32()) else {
                return
            }
            
            advanced = min(length, documentLength - unconsumedCopy.count)
            documentsData.append(contentsOf: unconsumedCopy)
            documentsData.append(contentsOf: UnsafeBufferPointer<Byte>(start: consuming, count: advanced))
            
            guard length > documentLength else {
                checkComplete()
                
                return
            }
        }
        
        return process(consuming: consuming.advanced(by: advanced), withLengthOf: length &- advanced)
    }
    
    func construct() -> ServerReply? {
        guard
            let requestId = requestId,
            let responseTo = responseTo,
            let flags = flags,
            let cursorID = cursorID,
            let startingFrom = startingFrom,
            let numbersReturned = numbersReturned,
            documentsComplete else {
                return nil
        }
        
        let docs = [Document](bsonBytes: documentsData)
        
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
