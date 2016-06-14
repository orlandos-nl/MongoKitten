import Foundation

#if !swift(>=3.0) || os(Linux)
    typealias TimeInterval = NSTimeInterval
    typealias Lock = NSLock
    typealias Condition = NSCondition
    
    extension String {
        struct Encoding {
            static let utf8 = NSUTF8StringEncoding
        }
    }
#endif

#if !swift(>=3.0)
    public typealias ErrorProtocol = ErrorType
    public typealias OptionSet = OptionSetType
    public typealias Sequence = SequenceType
    
    extension String {
        func lowercased() -> String {
            return self.lowercaseString
        }
    }
    
    extension UnsafeMutablePointer {
        var pointee: Memory {
            return self.memory
        }
    }
#endif
