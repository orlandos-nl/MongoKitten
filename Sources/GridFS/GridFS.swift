import MongoKitten
import NIO

extension CodingUserInfoKey {
    static let gridFS = CodingUserInfoKey(rawValue: "GridFS")!
}

public class GridFS {
    
    public typealias FileCursor = MappedCursor<FindCursor, File>
    
    let filesCollection: MongoKitten.Collection
    let chunksCollection: MongoKitten.Collection
    
    private var didEnsureIndexes: Bool = false
    
    var eventLoop: EventLoop {
        return filesCollection.database.connection.eventLoop
    }
    
    public init(named name: String, in database: Database) {
        self.filesCollection = database["\(name).files"]
        self.chunksCollection = database["\(name).chunks"]
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
    
    internal func ensureIndexes() -> EventLoopFuture<Void> {
        guard !didEnsureIndexes else {
            return eventLoop.newSucceededFuture(result: ())
        }
        
        didEnsureIndexes = true
        
        return filesCollection
            .find()
            .project(["_id": .included])
            .limit(1)
            .getFirstResult()
            .then { result in
                // Determine if the files collection is empty
                guard result == nil else {
                    return self.eventLoop.newSucceededFuture(result: ())
                }
                
                // TODO: Drivers MUST check whether the indexes already exist before attempting to create them. This supports the scenario where an application is running with read-only authorizations.
                
                return EventLoopFuture<Void>.andAll([
                    self.filesCollection.indexes.createCompound(named: "mongokitten_was_here", keys: [
                        "filename": .ascending,
                        "uploadDate": .ascending
                        ]),
                    self.chunksCollection.indexes.createCompound(named: "mongokitten_was_here", keys: [
                        "files_id": .ascending,
                        "n": .ascending
                        ], options: [.unique])
                    ], eventLoop: self.eventLoop)
        }
    }
    
}
