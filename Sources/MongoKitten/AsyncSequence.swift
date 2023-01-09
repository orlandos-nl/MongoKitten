import NIOCore
import NIO
import MongoClient
import MongoKittenCore

public final class QueryCursorAsyncIterator<Base: QueryCursor>: AsyncIteratorProtocol {
    fileprivate let cursor: Base
    private var finalized: FinalizedCursor<Base>?
    private var results = [Element]()
    
    fileprivate init(cursor: Base) {
        self.cursor = cursor
    }
    
    public func next() async throws -> Base.Element? {
        try Task.checkCancellation()
        
        let cursor: FinalizedCursor<Base>
        
        if let finalized = self.finalized {
            cursor = finalized
        } else {
            cursor = try await self.cursor.execute()
            self.finalized = cursor
        }
        
        // Repeat fetching more results
        // getMore can have 0 results while not drained
        // Because failable decoding can fail decoding all (101) results
        while !cursor.isDrained && results.isEmpty {
            try await results.append(contentsOf: cursor.nextBatch())
        }
        
        if results.isEmpty {
            return nil
        }
        
        return results.removeFirst()
    }
}

extension QueryCursor where Self: AsyncSequence {
    public func makeAsyncIterator() -> QueryCursorAsyncIterator<Self> {
        QueryCursorAsyncIterator(cursor: self)
    }
}

extension MappedCursor: AsyncSequence {}
extension FindQueryBuilder: AsyncSequence {}
extension AggregateBuilderPipeline: AsyncSequence {}

extension FinalizedCursor: AsyncSequence {
    public typealias Element = Base.Element
    
    public final class AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = FinalizedCursor.Element
        
        fileprivate let cursor: FinalizedCursor<Base>
        private var results = [Element]()
        let failable: Bool
        
        internal init(cursor: FinalizedCursor<Base>, failable: Bool) {
            self.cursor = cursor
            self.failable = failable
        }
        
        public func next() async throws -> Element? {
            if !results.isEmpty {
                return results.removeFirst()
            }
            
            // Repeat fetching more results
            // getMore can have 0 results while not drained
            // Because failable decoding can fail decoding all (101) results
            while !cursor.isDrained && results.isEmpty {
                try Task.checkCancellation()
                try await results.append(contentsOf: cursor.nextBatch(failable: failable))
            }
            
            if results.isEmpty {
                return nil
            }
            
            return results.removeFirst()
        }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(cursor: self, failable: false)
    }
}
