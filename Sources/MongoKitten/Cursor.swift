import NIO

public final class Cursor<Element> {
    let id: Int64
    var buffer: [Element]
    var drained = false
    let collection: Collection
    var batchSize = 101
    
    fileprivate init(id: Int64, buffer: [Element], collection: Collection) {
        self.id = id
        self.buffer = buffer
        self.collection = collection
    }
    
    func map<T>(_ transform: (Element) throws -> T) -> Cursor<T> {
        unimplemented()
    }
    
    func forEach(_ body: (Element) throws -> Void) -> EventLoopFuture<Void> {
        do {
            for element in buffer {
                try body(element)
            }
            
            
        } catch {
            return self.collection.eventLoop.newFailedFuture(error: error)
        }
    }
    
    func getMore() -> EventLoopFuture<Void> {
        return GetMore(cursorId: self.id, batchSize: batchSize, on: self.collection)
            .execute(on: self.collection.connection)
            .map { batch in
                batch.cursor.nextBatch
            }
    }
    
}

extension Cursor where Element == Document {
    internal convenience init(_ reply: CursorReply, collection: Collection) throws {
        self.init(id: reply.cursor.id, buffer: reply.cursor.firstBatch, collection: collection)
    }
}
