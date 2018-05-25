import MongoKitten
import NIO

public class Bucket {
    
    let filesCollection: MongoKitten.Collection
    let chunksCollection: MongoKitten.Collection
    
    init(named name: String = "fs", in database: Database) {
        self.filesCollection = database["\(name).files"]
        self.chunksCollection = database["\(name).chunks"]
    }
    
    func find() -> Cursor<File> {
        unimplemented()
    }
    
}
