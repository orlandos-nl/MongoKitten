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