import MongoKitten
import Dispatch
import NIO

public final class MeowDatabase: EventLoopGroup {
    public let raw: MongoDatabase
    public var eventLoop: EventLoop { return raw.eventLoop }
    
    public init(_ database: MongoDatabase) {
        self.raw = database
    }
    
    public func collection<M: BaseModel>(for model: M.Type) -> MeowCollection<M> {
        return MeowCollection<M>(database: self, named: M.collectionName)
    }
    
    public subscript<M: BaseModel>(type: M.Type) -> MeowCollection<M> {
        return collection(for: type)
    }
    
    public func makeIterator() -> EventLoopIterator {
        return raw.eventLoop.makeIterator()
    }
    
    public func next() -> EventLoop {
        return raw.eventLoop
    }
    
    public func shutdownGracefully(queue: DispatchQueue, _ callback: @escaping (Error?) -> Void) {
        raw.eventLoop.shutdownGracefully(queue: queue, callback)
    }
}
