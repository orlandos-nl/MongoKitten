import MongoKitten
import Dispatch
import NIO

public final class MeowDatabase {
    public let raw: MongoDatabase
    
    public init(_ database: MongoDatabase) {
        self.raw = database
    }
    
    public func collection<M: BaseModel>(for model: M.Type) -> MeowCollection<M> {
        return MeowCollection<M>(database: self, named: M.collectionName)
    }
    
    public subscript<M: BaseModel>(type: M.Type) -> MeowCollection<M> {
        return collection(for: type)
    }
}
