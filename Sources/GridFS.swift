//
//  GridFS.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 22/03/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import CryptoSwift
import BSON
import Foundation

/// A GridFS instance similar to a collection
public class GridFS {
    private let files: Collection
    private let chunks: Collection
    
    /// Initializes a GridFS Collection (bucket) in a given database
    public init(database: Database, bucketName: String = "fs") {
        files = database["\(bucketName).files"]
        chunks = database["\(bucketName).chunks"]
        
        // Make indexes
        do {
            try chunks.createIndex([(key: "files_id", asc: true), (key: "n", asc: true)], name: "chunksindex", partialFilterExpression: nil, buildInBackground: true, unique: true)
        } catch {}
        
        do {
            try files.createIndex([(key: "filename", asc: true), (key: "uploadDate", asc: true)], name: "filesindex", partialFilterExpression: nil, buildInBackground: true, unique: false)
        } catch {}
    }
    
    /// Get the chunks matching the file's ObjectID
    /// - parameter fileID: The ObjectID belonging to the file
    /// - returns: A cursor pointing to all chunks in the right order
    public func getFileCursor(fileID: ObjectId) throws -> Cursor<Document> {
        return try chunks.find(["files_id": fileID], sort: ["n": 1], projection: ["data": 1])
    }
    
    /// Finds all files matching an ObjectId (only one), MD5 hash (usually one) and filename (possibly more than one)
    /// - parameter id: Optional. Will select any Documents matching this ID (only one or none at all)
    /// - parameter md5: Optional. Will select any Documents matching this MD5 hash
    /// - parameter filename: Optional. Will select any Documents matching this filename
    /// - returns: A cursor pointing to all found files
    public func findFiles(id: ObjectId? = nil, md5: String? = nil, filename: String? = nil) throws -> Cursor<GridFSFile> {
        var filter = *[]
        
        if let id = id {
            filter += ["_id": id]
        }
        
        if let md5 = md5 {
            filter += ["md5": md5]
        }
        
        if let filename = filename {
            filter += ["filename": filename]
        }
        
        let cursor = try files.find(filter)
        
        let gridFSCursor: Cursor<GridFSFile> = Cursor(base: cursor, transform: { GridFSFile(document: $0, chunksCollection: self.chunks, filesCollection: self.files) })
        
        return gridFSCursor
    }
    
    /// Finds one file matching an ObjectId (only one), MD5 hash (usually one) and filename (possibly more than one)
    /// - parameter id: Optional. Will select any Documents matching this ID (only one or none at all)
    /// - parameter md5: Optional. Will select any Documents matching this MD5 hash
    /// - parameter filename: Optional. Will select any Documents matching this filename
    /// - returns: The found file -- if any
    public func findOneFile(id: ObjectId? = nil, md5: String? = nil, filename: String? = nil) throws -> GridFSFile? {
        var filter = *[]
        
        if let id = id {
            filter += ["_id": id]
        }
        
        if let md5 = md5 {
            filter += ["md5": md5]
        }
        
        if let filename = filename {
            filter += ["filename": filename]
        }
        
        guard let document = try files.findOne(filter) else {
            return nil
        }
        
        return GridFSFile(document: document, chunksCollection: chunks, filesCollection: files)
    }
    
    /// Stores a file given NSData, an optonal filename and using a chunksize
    /// - parameter data: An NSData object containing the information to be stored
    /// - parameter filename: Optional. The filename used to store this file
    /// - parameter chunkSize: The amount of data to be put into one chunks (maximum 15900000
    /// - returns: The ObjectID refering to the File in GridFS
    public func storeFile(data: NSData, filename: String? = nil, chunkSize: Int = 255000, contentType: String? = nil, metadata: BSONElement? = nil) throws -> ObjectId {
        return try self.storeFile(data.arrayOfBytes(), filename: filename, chunkSize: chunkSize, contentType: contentType, metadata: metadata)
    }
    
    /// Stores a file given NSData, an optonal filename and using a chunksize
    /// - parameter data: An NSData object containing the information to be stored
    /// - parameter filename: Optional. The filename used to store this file
    /// - parameter chunkSize: The amount of data to be put into one chunks (maximum 15900000
    /// - returns: The ObjectID refering to the File in GridFS
    public func storeFile(data: [UInt8], filename: String? = nil, chunkSize: Int = 255000, contentType: String? = nil, metadata: BSONElement? = nil) throws -> ObjectId {
        guard chunkSize < 16900000 else {
            throw MongoError.InvalidChunkSize(chunkSize: chunkSize)
        }
        
        var data = data
        let id = ObjectId()
        let dataSize = data.count
        
        var insertData = *["_id": id, "length": dataSize, "chunkSize": Int32(chunkSize), "uploadDate": NSDate.init(timeIntervalSinceNow: 0), "md5": data.md5().toHexString()]
        
        // Not supported yet
//        if let aliases = aliases {
//            
//        }
        
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
}

/// A file in GridFS
public struct GridFSFile {
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
    
    public func findChunks(skip: Int32 = 0, limit: Int32 = 0) throws -> Cursor<GridFSChunk> {
        let cursor = try chunksCollection.find(["files_id": id], sort: ["n": 1], skip: skip, limit: limit)
        
        return Cursor(base: cursor, transform: { GridFSChunk(document: $0, chunksCollection: self.chunksCollection, filesCollection: self.filesCollection) })
    }
}

public struct GridFSChunk {
    public let id: ObjectId
    public let filesID: ObjectId
    public let n: Int32
    public let data: Binary
    
    let chunksCollection: Collection
    let filesCollection: Collection
    
    internal init?(document: Document, chunksCollection: Collection, filesCollection: Collection) {
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