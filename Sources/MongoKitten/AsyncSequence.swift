import NIOCore
import NIO
import MongoClient
import MongoKittenCore

@available(macOS 10.15, iOS 13, watchOS 8, tvOS 15, *)
extension MappedCursor: AsyncSequence {
    public final class AsyncIterator: AsyncIteratorProtocol {
        fileprivate let cursor: MappedCursor<Base, Element>
        private var finalized: FinalizedCursor<MappedCursor<Base, Element>>?
        private var results = [Element]()
        
        fileprivate init(cursor: MappedCursor<Base, Element>) {
            self.cursor = cursor
        }
        
        public func next() async throws -> Element? {
            try Task.checkCancellation()
            
            let cursor: FinalizedCursor<MappedCursor<Base, Element>>
            
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
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(cursor: self)
    }
}

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
