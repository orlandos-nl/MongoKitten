public final class MongoTransactionDatabase: MongoDatabase {
    public func commit() -> EventLoopFuture<Void> {
        self.pool.next(for: .writable).flatMap { connection in
            connection.executeCodable(
                CommitTransaction(),
                namespace: .administrativeCommand,
                in: self.transaction,
                sessionId: self.sessionId
            ).decodeReply(OK.self).map { _ in }
        }._mongoHop(to: self.hoppedEventLoop)
    }
    
    public func abort() -> EventLoopFuture<Void> {
        self.pool.next(for: .writable).flatMap { connection in
            connection.executeCodable(
                AbortTransaction(),
                namespace: .administrativeCommand,
                in: self.transaction,
                sessionId: self.sessionId
            ).decodeReply(OK.self).map { _ in }
        }._mongoHop(to: self.hoppedEventLoop)
    }
}

struct CommitTransaction: Codable {
    private(set) var commitTransaction = 1
    
    init() {}
}

struct AbortTransaction: Codable {
    private(set) var abortTransaction = 1
    
    init() {}
}

internal struct OK: Decodable {
    private enum CodingKeys: String, CodingKey {
        case ok
    }
    
    private let ok: Int

    public var isSuccessful: Bool { ok == 1 }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try container.decode(Int.self, forKey: .ok)
    }
}
