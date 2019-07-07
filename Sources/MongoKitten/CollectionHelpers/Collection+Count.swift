import MongoCore
import NIO

extension MongoCollection {
    public func count(_ query: Document? = nil) -> EventLoopFuture<Int> {
        return pool.next(for: .basic).flatMap { connection in
            return connection.executeCodable(
                CountCommand(on: self.name, where: query),
                namespace: self.database.commandNamespace
            )
        }.decode(CountReply.self).map { $0.count }
    }
    
    public func count<Query: MongoKittenQuery>(_ query: Query? = nil) -> EventLoopFuture<Int> {
        return count(query?.makeDocument())
    }
}
