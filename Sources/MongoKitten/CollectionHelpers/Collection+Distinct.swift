import MongoCore
import NIO

extension MongoCollection {
    public func distinctValues(forKey key: String, where query: Document? = nil) -> EventLoopFuture<[Primitive]> {
        return pool.next(for: .basic).flatMap { connection in
            let command = DistinctCommand(onKey: key, inCollection: self.name)
            return connection.executeCodable(command, namespace: self.database.commandNamespace)
        }.decode(DistinctReply.self).map { $0.distinctValues }
    }
}
