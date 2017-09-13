extension Int32 {
    internal init<S : Swift.Collection>(_ s: S) where S.Iterator.Element == UInt8, S.Index == Int {
        var val: Int32 = 0
        val |= s.count > 3 ? Int32(s[s.startIndex.advanced(by: 3)]) << 24 : 0
        val |= s.count > 2 ? Int32(s[s.startIndex.advanced(by: 2)]) << 16 : 0
        val |= s.count > 1 ? Int32(s[s.startIndex.advanced(by: 1)]) << 8 : 0
        val |= s.count > 0 ? Int32(s[s.startIndex]) : 0
        
        self = val
    }
}

extension Int {
    internal init<S : Swift.Collection>(_ s: S) where S.Iterator.Element == UInt8, S.Index == Int {
        var number: Int = 0
        number |= s.count > 7 ? Int(s[s.startIndex.advanced(by: 7)]) << 56 : 0
        number |= s.count > 6 ? Int(s[s.startIndex.advanced(by: 6)]) << 48 : 0
        number |= s.count > 5 ? Int(s[s.startIndex.advanced(by: 5)]) << 40 : 0
        number |= s.count > 4 ? Int(s[s.startIndex.advanced(by: 4)]) << 32 : 0
        number |= s.count > 3 ? Int(s[s.startIndex.advanced(by: 3)]) << 24 : 0
        number |= s.count > 2 ? Int(s[s.startIndex.advanced(by: 2)]) << 16 : 0
        number |= s.count > 1 ? Int(s[s.startIndex.advanced(by: 1)]) << 8 : 0
        number |= s.count > 0 ? Int(s[s.startIndex.advanced(by: 0)]) << 0 : 0
        
        self = number
    }
}

