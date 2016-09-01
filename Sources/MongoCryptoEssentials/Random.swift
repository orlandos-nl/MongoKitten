#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public func generateNumber(between first: Int32, and second: Int32) -> Int32 {
    var low : Int32
    var high : Int32
    
    if first <= second {
        low  = first
        high = second
    }
    else {
        low  = second
        high = first
    }
    
    let modular = UInt32((high - low) + 1)
    #if os(Linux)
        let random = UInt32(bitPattern: rand())
    #else
        let random = arc4random()
    #endif
    
    return Int32(random % modular) + low
}

public func generateNumberSequenceBetween(_ first: Int32, and second: Int32, ofLength length: Int, withUniqueValues unique: Bool) -> [Int32] {
    if length < 1 {
        return [Int32]()
    }
    
    var sequence : [Int32] = [Int32](repeating: 0, count: length)
    if unique {
        if (first <= second && (length > (second - first) + 1)) ||
            (first > second  && (length > (first - second) + 1)) {
            return [Int32]()
        }
        
        var loop : Int = 0
        while loop < length {
            let number = generateNumber(between: first, and: second)
            
            // If the number is unique, add it to the sequence
            if !isNumber(number: number, inSequence: sequence, ofLength: loop) {
                sequence[loop] = number
                loop += 1
            }
        }
    }
    else {
        // Repetitive values are allowed
        for i in 0..<length {
            sequence[i] = generateNumber(between: first, and: second)
        }
    }
    
    return sequence
}

public func generateRandomSignedData(length: Int) -> [Int8] {
    guard length >= 1 else {
        return []
    }
    
    var sequence = generateNumberSequenceBetween(-128, and: 127, ofLength: length, withUniqueValues: false)
    var randomData : [Int8] = [Int8](repeating: 0, count: length)
    
    for i in 0 ..< length {
        randomData[i] = Int8(sequence[i])
    }
    
    return randomData
}

public func isNumber(number: Int32, inSequence sequence: [Int32], ofLength length: Int) -> Bool {
    if length < 1 || length > sequence.count {
        return false
    }
    
    for i in 0 ..< length where sequence[i] == number {
        return true
    }
    
    // The number was not found, return false
    return false
}
