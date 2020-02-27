public final class MongoTransactionDatabase: MongoDatabase {
    public func commit() -> EventLoopFuture<Void> {
        self.pool.next(for: .writable).flatMap { connection in
            connection.executeCodable(
                CommitTransaction(),
                namespace: .administrativeCommand,
                in: self.transaction,
                sessionId: self.sessionId
            ).decode(OK.self).map { _ in }
        }
    }
    
    public func abort() -> EventLoopFuture<Void> {
        self.pool.next(for: .writable).flatMap { connection in
            connection.executeCodable(
                AbortTransaction(),
                namespace: .administrativeCommand,
                in: self.transaction,
                sessionId: self.sessionId
            ).decode(OK.self).map { _ in }
        }
    }
}

struct CommitTransaction: Codable {
    let commitTransaction = 1
    
    init() {}
}

struct AbortTransaction: Codable {
    let abortTransaction = 1
    
    init() {}
}

internal struct OK: Decodable {
    private enum CodingKeys: String, CodingKey {
        case ok
    }
    
    private let ok: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try container.decode(Int.self, forKey: .ok)
    }
}
