import MongoCore
import NIO

extension MongoCollection {
    public func count(_ query: Document? = nil) -> EventLoopFuture<Int> {
        guard transaction == nil else {
            return makeTransactionError()
        }
        
        return pool.next(for: .basic).flatMap { connection in
            return connection.executeCodable(
                CountCommand(on: self.name, where: query),
                namespace: self.database.commandNamespace,
                sessionId: self.sessionId ?? connection.implicitSessionId
            )
        }.decode(CountReply.self).map { $0.count }._mongoHop(to: hoppedEventLoop)
    }
    
    public func count<Query: MongoKittenQuery>(_ query: Query? = nil) -> EventLoopFuture<Int> {
        return count(query?.makeDocument())
    }
}
