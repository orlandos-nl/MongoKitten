import NIO

extension MongoCollection {
    public func createIndex(named name: String, keys: Document) -> EventLoopFuture<Void> {
        return self.pool.next(for: .writable).flatMap { connection in
            return connection.executeCodable(
                CreateIndexes(
                    collection: self.name,
                    indexes: [CreateIndexes.Index(named: name, keys: keys)]
                ),
                namespace: self.database.commandNamespace
            )
        }.flatMapThrowing { reply in
            return try reply.assertOK()
        }
    }
}
