import MongoKitten
import Foundation

class Chunk: Codable {
    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case filesId = "files_id"
        case sequenceNumber = "n"
        case data
    }
    
    var id = ObjectId()
    var filesId: Primitive
    var sequenceNumber: Int
    var data: Binary
    
    init(filesId: ObjectId, sequenceNumber: Int, data: Binary) {
        self.filesId = filesId
        self.sequenceNumber = sequenceNumber
        self.data = data
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeBSONPrimitive(filesId, forKey: .filesId)
        try container.encode(sequenceNumber, forKey: .sequenceNumber)
        try container.encode(data, forKey: .data)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(ObjectId.self, forKey: .id)
        self.filesId = try container.decode(Primitive.self, forKey: .filesId)
        self.sequenceNumber = try container.decode(Int.self, forKey: .sequenceNumber)
        self.data = try container.decode(Binary.self, forKey: .data)
    }
}
