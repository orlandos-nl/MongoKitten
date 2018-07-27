import MongoKitten
import NIO

extension CodingUserInfoKey {
    static let gridFS = CodingUserInfoKey(rawValue: "GridFS")!
}

public class GridFS {
    
    public typealias FileCursor = MappedCursor<FindCursor, File>
    
    let filesCollection: MongoKitten.Collection
    let chunksCollection: MongoKitten.Collection
    
    private init(named name: String, in database: Database) {
        self.filesCollection = database["\(name).files"]
        self.chunksCollection = database["\(name).chunks"]
    }
    
    /// Returns a GridFS bucket with the given `name` in the given `database`.
    public static func `in`(database: Database, named name: String = "fs") -> EventLoopFuture<GridFS> {
        // TODO: Ensure indexes
        return database.connection.eventLoop.newSucceededFuture(result: GridFS(named: name, in: database))
    }
    
    public func find(_ query: Query) -> FileCursor {
        var decoder = BSONDecoder()
        decoder.userInfo = [
            .gridFS: self as Any
        ]
        
        return filesCollection
            .find(query)
            .decode(File.self, using: decoder)
    }
    
    public func findFile(_ query: Query) -> EventLoopFuture<File?> {
        return self.find(query)
            .limit(1)
            .getFirstResult()
    }
    
    public func findFile(byId id: ObjectId) -> EventLoopFuture<File?> {
        return self.findFile("_id" == id)
    }
    
    // TODO: Cancellable, streaming writes & reads
    // TODO: Non-streaming writes & reads
    
}
