import MongoCore

internal struct KillCursorsCommand: Codable {
    let killCursors: String
    var cursors: [Int64]

    init(_ cursors: [Int64], inCollection collection: String) {
        self.killCursors = collection
        self.cursors = cursors
    }
}

internal struct KillCursorsReply: Decodable {
    let cursorsKilled: [Int64]
    let cursorsAlive: [Int64]
    let ok: Int
}
