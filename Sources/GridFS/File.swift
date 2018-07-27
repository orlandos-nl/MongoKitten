import MongoKitten
import Foundation

enum GridFSError: Error {
    case missingGridFSUserInfo
}

public class File: Codable {
    
    private var fs: GridFS
    
    // TODO: allow different _id types, see https://github.com/mongodb/specifications/blob/master/source/gridfs/gridfs-spec.rst#before-read-operations - Why have we changed our mind about requiring the file id to be an ObjectId?
    var _id: ObjectId
    public internal(set) var length: Int
    public private(set) var chunkSize: Int = 261_120 // 255 kB
    public let uploadDate: Date
    public internal(set) var md5: String
    public var filename: String?
    
    @available(*, deprecated, message: "Applications wishing to store a contentType should add a contentType field to the metadata document instead.")
    public var contentType: String?
    
    @available(*, deprecated, message: "Applications wishing to store aliases should add an aliases field to the metadata document instead.")
    public var aliasses: [String]?
    
    public var metadata: Primitive?
    
    internal init() {
        fatalError("unimplemented")
    }
    
    private enum CodingKeys: String, CodingKey {
        case _id, length, chunkSize, uploadDate, md5, filename, contentType, aliasses, metadata
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let userInfo = decoder.userInfo
        guard let fs = userInfo[.gridFS] as? GridFS else {
            throw GridFSError.missingGridFSUserInfo
        }
        
        self.fs = fs
        self._id = try container.decode(ObjectId.self, forKey: ._id)
        self.length = try container.decode(Int.self, forKey: .length)
        self.chunkSize = try container.decode(Int.self, forKey: .chunkSize)
        self.uploadDate = try container.decode(Date.self, forKey: .uploadDate)
        self.md5 = try container.decode(String.self, forKey: .md5)
        self.filename = try container.decodeIfPresent(String.self, forKey: .filename)
        self.contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        self.aliasses = try container.decodeIfPresent([String].self, forKey: .aliasses)
        self.metadata = try container.decodeIfPresent(Primitive.self, forKey: .metadata)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = try encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self._id, forKey: ._id)
        try container.encode(self.length, forKey: .length)
        try container.encode(self.chunkSize, forKey: .chunkSize)
        try container.encode(self.uploadDate, forKey: .uploadDate)
        try container.encode(self.md5, forKey: .md5)
        try container.encode(self.filename, forKey: .filename)
        try container.encode(self.contentType, forKey: .contentType)
        try container.encode(self.aliasses, forKey: .aliasses)
        try container.encodeBSONPrimitive(self.metadata, forKey: .metadata)
    }
    
}
