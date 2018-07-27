import MongoKitten
import Foundation

enum GridFSError: Error {
    case missingGridFSUserInfo
}

public class File: Codable {
    
    private var fs: GridFS
    
    var _id: ObjectId
    public internal(set) var length: Int
    public private(set) var chunkSize: Int = 261_120 // 255 kB
    public let uploadDate: Date
    public internal(set) var md5: String
    public var filename: String?
    public var contentType: String?
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
