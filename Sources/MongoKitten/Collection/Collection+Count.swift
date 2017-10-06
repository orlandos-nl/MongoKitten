import Async

extension Collection {
    public func count(
        _ filter: Query? = nil
    ) throws -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        
        return try count.execute(on: database)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: Range<Int>
    ) throws -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.skip = range.lowerBound
        count.limit = range.upperBound - range.lowerBound
        
        return try count.execute(on: database)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: ClosedRange<Int>
    ) throws -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.skip = range.lowerBound
        count.limit = (range.upperBound + 1) - range.lowerBound
        
        return try count.execute(on: database)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: PartialRangeFrom<Int>
    ) throws -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.skip = range.lowerBound
        
        return try count.execute(on: database)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: PartialRangeUpTo<Int>
    ) throws -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.limit = range.upperBound
        
        return try count.execute(on: database)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: PartialRangeThrough<Int>
    ) throws -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.limit = range.upperBound + 1
        
        return try count.execute(on: database)
    }
}
