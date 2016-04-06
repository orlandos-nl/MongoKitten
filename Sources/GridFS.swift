//
//  GridFS.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 22/03/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import C7
import BSON
import Foundation
import MD5

/// A GridFS instance similar to a collection
public class GridFS {
    private let files: Collection
    private let chunks: Collection
    
    /// Initializes a GridFS Collection (bucket) in a given database
    /// - parameter in: In which database does this GridFS bucket reside
    /// - parameter named: The optional name of this GridFS bucket (by default "fs")
    public init(in database: Database, named bucketName: String = "fs") throws {
        files = database["\(bucketName).files"]
        chunks = database["\(bucketName).chunks"]
        
        // Make indexes
        try chunks.createIndex(with: [(key: "files_id", ascending: true), (key: "n", ascending: true)], named: "chunksindex", filter: nil, buildInBackground: true, unique: true)
        
        try files.createIndex(with: [(key: "filename", ascending: true), (key: "uploadDate", ascending: true)], named: "filesindex", filter: nil, buildInBackground: true, unique: false)
    }
    
    /// Finds using all files matching this ObjectID
    /// - parameter byID: The ID to look for
    /// - returns: A cursor pointing to all resulting files
    public func find(byID id: ObjectId) throws -> Cursor<File> {
        return try self.find(matching: ["_id": id])
    }
    
    /// Finds using all files file matching this filename
    /// - parameter filter: The filename to look for
    /// - returns: A cursor pointing to all resulting files
    public func find(byName filename: String) throws -> Cursor<File> {
        return try self.find(matching: ["filename": filename])
    }
    
    /// Finds using all files matching this MD5 hash
    /// - parameter filter: The hash to look for
    /// - returns: A cursor pointing to all resulting files
    public func find(byHash hash: String) throws -> Cursor<File> {
        return try self.find(matching: ["md5": hash])
    }
    
    /// Finds the first file matching this ObjectID
    /// - parameter byID: The hash to look for
    /// - returns: The resulting file
    public func findOne(byID id: ObjectId) throws -> File? {
        return try self.find(matching: ["_id": id]).makeIterator().next()
    }
    
    /// Finds the first file matching this filename
    /// - parameter byName: The filename to look for
    /// - returns: The resulting file
    public func findOne(byName filename: String) throws -> File? {
        return try self.find(matching: ["filename": filename]).makeIterator().next()
    }
    
    /// Finds the first file matching this MD5 hash
    /// - parameter byHash: The hash to look for
    /// - returns: The resulting file
    public func findOne(byHash hash: String) throws -> File? {
        return try self.find(matching: ["md5": hash]).makeIterator().next()
    }
    
    /// Finds using a matching filter
    /// - parameter filter: The filter to use
    /// - returns: A cursor pointing to all resulting files
    public func find(matching filter: Document) throws -> Cursor<File> {
        let cursor = try files.find(matching: filter)
        
        let gridFSCursor: Cursor<File> = Cursor(base: cursor, transform: { File(document: $0, chunksCollection: self.chunks, filesCollection: self.files) })
        
        return gridFSCursor
    }
    
    /// Stores the data in GridFS
    /// - parameter data: The data to store
    /// - parameter named: The optional filename to use for this data
    /// - parameter withType: The optional MIME type to use for this data
    /// - parameter usingMetadata: The optional metadata to store with this file
    /// - parameter inChunksOf: The amount of bytes to put in one chunk
    public func store(data data: [Byte], named filename: String? = nil, withType contentType: String? = nil, usingMetadata metadata: BSONElement? = nil, inChunksOf chunkSize: Int = 255000) throws -> ObjectId {
        guard chunkSize < 15000000 else {
            throw MongoError.InvalidChunkSize(chunkSize: chunkSize)
        }
        
        var data = data
        let id = ObjectId()
        let dataSize = data.count
        
        var insertData = *["_id": id, "length": dataSize, "chunkSize": Int32(chunkSize), "uploadDate": NSDate.init(timeIntervalSinceNow: 0), "md5": MD5.calculate(data).toHexString()]
        
        if let contentType = contentType {
            insertData += ["contentType": contentType]
        }
        
        if let metadata = metadata {
            insertData += ["metadata": metadata]
        }
        
        _ = try files.insert(insertData)
        
        var n = 0
        
        while !data.isEmpty {
            let smallestMax = min(data.count, chunkSize)
            
            let chunk = Array(data[0..<smallestMax])
            
            _ = try chunks.insert(["files_id": id,
                                   "n": n,
                                   "data": Binary(data: chunk)])
            
            n += 1
            
            data.removeFirst(smallestMax)
        }
        
        return id
    }
    
    /// Stores the data in GridFS
    /// - parameter data: The data to store
    /// - parameter named: The optional filename to use for this data
    /// - parameter withType: The optional MIME type to use for this data
    /// - parameter usingMetadata: The optional metadata to store with this file
    /// - parameter inChunksOf: The amount of bytes to put in one chunk
    public func store(data data: NSData, named filename: String? = nil, withType contentType: String? = nil, usingMetadata metadata: BSONElement? = nil, inChunksOf chunkSize: Int = 255000) throws -> ObjectId {
        return try self.store(data: data.arrayOfBytes(), named: filename, withType: contentType, usingMetadata: metadata, inChunksOf: chunkSize)
    }
    
    /// Stores the data in GridFS
    /// - parameter data: The data to store
    /// - parameter named: The optional filename to use for this data
    /// - parameter withType: The optional MIME type to use for this data
    /// - parameter usingMetadata: The optional metadata to store with this file
    /// - parameter inChunksOf: The amount of bytes to put in one chunk
    public func store(data data: Data, named filename: String? = nil, withType contentType: String? = nil, usingMetadata metadata: BSONElement? = nil, inChunksOf chunkSize: Int = 255000) throws -> ObjectId {
        return try self.store(data: data.bytes, named: filename, withType: contentType, usingMetadata: metadata, inChunksOf: chunkSize)
    }
    
    /// A file in GridFS
    public class File {
        /// The ObjectID for this file
        public let id: ObjectId
        
        /// The amount of bytes in this file
        public let length: Int32
        
        /// The amount of data per chunk
        public let chunkSize: Int32
        
        /// The date on which this file has been uploaded
        public let uploadDate: NSDate
        
        /// The file's MD5 hash
        public let md5: String
        
        /// The file's name (if any)
        public let filename: String?
        
        /// The file's content-type (MIME) (if any)
        public let contentType: String?
        
        /// The aliases for this file (if any)
        public let aliases: [String]?
        
        /// The metadata for this file (if any)
        public let metadata: BSONElement?
        
        /// The collection where the chunks are stored
        let chunksCollection: Collection
        
        /// The collection where this file is stored
        let filesCollection: Collection
        
        /// Initializes from a file-collection Document
        internal init?(document: Document, chunksCollection: Collection, filesCollection: Collection) {
            guard let id = document["_id"]?.objectIdValue,
                length = document["length"]?.int32Value,
                chunkSize = document["chunkSize"]?.int32Value,
                uploadDate = document["uploadDate"]?.dateValue,
                md5 = document["md5"]?.stringValue
                else {
                    return nil
            }
            
            self.chunksCollection = chunksCollection
            self.filesCollection = filesCollection
            
            self.id = id
            self.length = length
            self.chunkSize = chunkSize
            self.uploadDate = uploadDate
            self.md5 = md5
            
            self.filename = document["filename"]?.stringValue
            self.contentType = document["contentType"]?.stringValue
            
            var aliases = [String]()
            
            for alias in document["aliases"]?.documentValue?.arrayValue ?? [] {
                if let alias = alias.stringValue {
                    aliases.append(alias)
                }
            }
            
            self.aliases = aliases
            self.metadata = document["metadata"]
        }
        
        /// Finds all or specific chunks
        public func read(from start: Int = 0, to end: Int? = nil) throws -> [Byte] {
            let remainderValue = start % Int(self.chunkSize)
            let skipChunks = (start - remainderValue) / Int(self.chunkSize)
            
            var bytesRequested = Int(self.length) - start
            
            if let end = end {
                guard start > end else {
                    throw MongoError.NegativeBytesRequested(start: start, end: end)
                }
                
                bytesRequested = end - start
            }
            
            let lastByte = start + bytesRequested
            let lastChunkRemainder = lastByte % Int(self.chunkSize)
            let finalReduction = Int(self.chunkSize) - lastChunkRemainder
            
            var endChunk = (lastByte - lastChunkRemainder) / Int(self.chunkSize)
            
            if lastChunkRemainder > 0 {
                endChunk += 1
            }
            
            let cursor = try chunksCollection.find(matching: ["files_id": id], sortedBy: ["n": 1], skipping: Int32(skipChunks), limitedTo: Int32(endChunk - skipChunks))
            let chunkCursor = Cursor(base: cursor, transform: { Chunk(document: $0, chunksCollection: self.chunksCollection, filesCollection: self.filesCollection) })
            var allData = [Byte](repeating: 0, count: (endChunk - skipChunks) * Int(self.chunkSize))
            
            for chunk in chunkCursor {
                allData.append(contentsOf: chunk.data.data)
            }
            
            return Array(allData[remainderValue..<allData.count - finalReduction])
        }
        
        /// A GridFS Byte Chunk that's part of a file
        private class Chunk {
            /// The ID of this chunk
            let id: ObjectId
            
            /// The ID of the file that this chunk is a part of
            let filesID: ObjectId
            
            /// Which chunk we are
            let n: Int32
            
            /// The data for our chunk
            let data: Binary
            
            /// The chunk Collection which this chunk is in
            let chunksCollection: Collection
            
            /// The files collection where our file is stored
            let filesCollection: Collection
            
            /// Initializes with a Document found when looking for chunks
            init?(document: Document, chunksCollection: Collection, filesCollection: Collection) {
                guard let id = document["_id"]?.objectIdValue,
                    filesID = document["files_id"]?.objectIdValue,
                    n = document["n"]?.int32Value,
                    data = document["data"]?.binaryValue else {
                        return nil
                }
                
                self.chunksCollection = chunksCollection
                self.filesCollection = filesCollection
                
                self.id = id
                self.filesID = filesID
                self.n = n
                self.data = data
            }
        }
    }
}