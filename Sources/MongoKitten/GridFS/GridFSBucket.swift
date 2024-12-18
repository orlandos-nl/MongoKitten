import NIO
import Foundation

extension CodingUserInfoKey {
    static let gridFS = CodingUserInfoKey(rawValue: "GridFS")!
}

/// A GridFS Bucket that can be used to upload and download files to and from GridFS in a MongoDB database.
/// 
/// GridFS is MongoDB's specification for storing and retrieving large files such as images,
/// audio files, video files, or other binary data that exceeds the BSON document size limit of 16MB.
///
/// ## Basic Usage
/// ```swift
/// // Create a GridFS bucket
/// let gridFS = GridFSBucket(in: database)
///
/// // Upload a file
/// let file = try await gridFS.upload(
///     fileData,
///     filename: "document.pdf",
///     metadata: [
///         "contentType": "application/pdf",
///         "uploadedBy": "user123",
///         "category": "documents"
///     ]
/// )
///
/// // Find and download a file
/// if let file = try await gridFS.findFile("filename" == "document.pdf") {
///     let data = try await file.reader.readData()
///     // Process the file data
/// }
/// ```
///
/// ## Chunked Uploads
/// For large files or streaming uploads:
/// ```swift
/// let writer = try await GridFSFileWriter(toBucket: gridFS)
///
/// // Stream data chunks
/// for chunk in dataChunks {
///     try await writer.write(data: chunk)
/// }
///
/// // Finalize the upload
/// let file = try await writer.finalize(
///     filename: "large-video.mp4",
///     metadata: ["contentType": "video/mp4"]
/// )
/// ```
///
/// ## File Operations
/// ```swift
/// // List all PDF files
/// let pdfs = gridFS.find([
///     "filename": ["$regex": ".*\\.pdf$"],
///     "metadata.contentType": "application/pdf"
/// ])
///
/// // Delete a file
/// try await gridFS.deleteFile(byId: fileId)
/// ```
///
/// ## Performance Considerations
/// - The default chunk size is 255KB, which is suitable for most use cases
/// - Larger chunk sizes reduce the number of chunks but increase memory usage
/// - Smaller chunk sizes are better for streaming but create more database operations
/// - GridFS automatically creates indexes on the files and chunks collections
///
/// ## Implementation Details
/// GridFS stores files in two collections:
/// - `{bucketName}.files`: Stores file metadata
/// - `{bucketName}.chunks`: Stores the actual file data in chunks
///
/// [See the specification](https://github.com/mongodb/specifications/blob/master/source/gridfs/gridfs-spec.rst#indexes)
public final class GridFSBucket {
    /// The default chunk size for GridFS files in bytes (255 kB)
    public static let defaultChunkSize: Int32 = 261_120
    
    /// The files collection for this GridFS bucket. This is where the file metadata is stored.
    public let filesCollection: MongoCollection

    /// The chunks collection for this GridFS bucket. This is where the actual file data is stored.
    public let chunksCollection: MongoCollection
    
    private var didEnsureIndexes = false
    
    /// Creates a new GridFSBucket for the given database and collection name (defaulting to "fs")
    public init(named name: String = "fs", in database: MongoDatabase) {
        self.filesCollection = database[name + ".files"]
        self.chunksCollection = database[name + ".chunks"]
    }
    
    /// Uploads a file to GridFS and returns the GridFSFile that was created for it.
    public func upload(_ data: Data, filename: String? = nil, id: Primitive = ObjectId(), metadata: Document? = nil, chunkSize: Int32 = GridFSBucket.defaultChunkSize) async throws -> GridFSFile {
        var buffer = GridFSFileWriter.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        
        let writer = try await GridFSFileWriter(fs: self, fileId: id, chunkSize: chunkSize, buffer: buffer)
        return try await writer.finalize(filename: filename, metadata: metadata)
    }
    
    /// Uploads a file to GridFS and returns the GridFSFile that was created for it.
    public func upload(_ buffer: ByteBuffer, filename: String? = nil, id: Primitive = ObjectId(), metadata: Document? = nil, chunkSize: Int32 = GridFSBucket.defaultChunkSize) async throws -> GridFSFile {
        let writer = try await GridFSFileWriter(fs: self, fileId: id, chunkSize: chunkSize, buffer: buffer)
        return try await writer.finalize(filename: filename, metadata: metadata)
    }
    
    /// Lists all files in this GridFS bucket that match the given query.
    /// - Parameter query: The query to match files with
    /// - Returns: A cursor that can be used to iterate over all files that match the query
    public func find<MKQ: MongoKittenQuery>(_ query: MKQ) -> MappedCursor<FindQueryBuilder, GridFSFile> {
        find(query.makeDocument())
    }
    
    /// Lists all files in this GridFS bucket that match the given query. The query is a MongoDB query document.
    /// - Parameter query: The query to match files with
    /// - Returns: A cursor that can be used to iterate over all files that match the query
    public func find(_ query: Document) -> MappedCursor<FindQueryBuilder, GridFSFile> {
        var decoder = BSONDecoder()
        decoder.userInfo = [
            .gridFS: self as Any
        ]
        
        return filesCollection
            .find(query)
            .decode(GridFSFile.self, using: decoder)
    }
    
    /// Lists a single file in this GridFS bucket that match the given query.
    /// - Parameter query: The query to match files with
    /// - Returns: The first file that matches the query or `nil` if no file matches
    public func findFile<MKQ: MongoKittenQuery>(_ query: MKQ) async throws -> GridFSFile? {
        try await findFile(query.makeDocument())
    }

    /// Finds a single file in this GridFS bucket that matches the given query. The query is a MongoDB query document.
    /// - Parameter query: The query to match files with
    /// - Returns: The first file that matches the query or `nil` if no file matches
    public func findFile(_ query: Document) async throws -> GridFSFile? {
        var decoder = BSONDecoder()
        decoder.userInfo = [
            .gridFS: self as Any
        ]
        
        return try await filesCollection
            .find(query)
            .limit(1)
            .decode(GridFSFile.self, using: decoder)
            .firstResult()
    }
    
    /// Finds a single file in this GridFS bucket that matches `_id == id``.
    /// 
    /// - Parameter id: The `_id` of the file to find
    public func findFile(byId id: Primitive) async throws -> GridFSFile? {
        return try await self.findFile(["_id": id])
    }
    
    /// Deletes a file from GridFS and all of its chunks.
    /// - Parameter file: The `_id` of the file to delete
    public func deleteFile(byId id: Primitive) async throws {
        try await self.chunksCollection.deleteAll(where: ["files_id": id])
        try await self.filesCollection.deleteAll(where: ["_id": id])
    }
    
    internal func ensureIndexes() async throws {
        if didEnsureIndexes {
            return
        }
        
        didEnsureIndexes = true
        
        let findCollection = filesCollection
            .find()
            .project(["_id": .included])
            .limit(1)
        
        // Determine if the files collection is empty
        guard try await findCollection.firstResult() == nil else {
            return
        }
        
        // TODO: Drivers MUST check whether the indexes already exist before attempting to create them. This supports the scenario where an application is running with read-only authorizations.
        
        try await self.filesCollection.createIndex(
            named: "MongoKitten_GridFS",
            keys: [
                "filename": 1,
                "uploadDate": 1
            ]
        )
        try await self.chunksCollection.createIndex(
            named: "MongoKitten_GridFS",
            keys: [
                "files_id": 1,
                "n": 1
            ]
        )
    }
}
