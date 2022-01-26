public final class MongoTransactionDatabase: MongoDatabase {
    public func commit() async throws {
        _ = try await pool.next(for: .writable).executeCodable(
            CommitTransaction(),
            decodeAs: OK.self,
            namespace: .administrativeCommand,
            in: self.transaction,
            sessionId: self.sessionId
        )
    }
    
    public func abort() async throws {
        _ = try await pool.next(for: .writable).executeCodable(
            AbortTransaction(),
            decodeAs: OK.self,
            namespace: .administrativeCommand,
            in: self.transaction,
            sessionId: self.sessionId
        )
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
