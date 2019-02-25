import Foundation
import NIO

#if !os(iOS)
import MongoKitten
#endif

public struct FileReader {
    
    public let file: File
    
    internal init(file: File) {
        self.file = file
    }
    
    public func readAll() -> EventLoopFuture<Data> {
        return file.fs.chunksCollection
            .find("files_id" == file._id)
            .sort(["n": .ascending])
            .decode(Chunk.self)
            .getAllResults()
            .map { chunks in
                return chunks.reduce(into: Data(capacity: self.file.length)) { result, chunk in
                    result.append(chunk.data.data)
                }
        }
    }
    
}
