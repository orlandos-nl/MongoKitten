import MongoKitten

class Chunk: Codable {
    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case filesId = "files_id"
        case sequenceNumber = "n"
        case data
    }
    
    var id = ObjectId()
    var filesId: ObjectId
    var sequenceNumber: Int
    var data: Binary
    
    init(filesId: ObjectId, sequenceNumber: Int, data: Binary) {
        self.filesId = filesId
        self.sequenceNumber = sequenceNumber
        self.data = data
    }
}
