import Async

extension Collection {
    public func count(
        _ filter: Query? = nil
    ) -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        
        return count.execute(on: self.connection)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: Range<Int>
    ) -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.skip = range.lowerBound
        count.limit = range.upperBound - range.lowerBound
        
        return count.execute(on: self.connection)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: ClosedRange<Int>
    ) -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.skip = range.lowerBound
        count.limit = (range.upperBound + 1) - range.lowerBound
        
        return count.execute(on: self.connection)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: PartialRangeFrom<Int>
    ) -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.skip = range.lowerBound
        
        return count.execute(on: self.connection)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: PartialRangeUpTo<Int>
    ) -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.limit = range.upperBound
        
        return count.execute(on: self.connection)
    }
    
    public func count(
        _ filter: Query? = nil,
        in range: PartialRangeThrough<Int>
    ) -> Future<Int> {
        var count = Count(on: self)
        count.query = filter
        count.limit = range.upperBound + 1
        
        return count.execute(on: self.connection)
    }
}
