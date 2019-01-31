import NIO

extension Cluster {
    /// Lists all databases within this cluster as a MongoKitten Database
    ///
    /// This includes the adminsitrative database(s)
    public func listDatabases() -> EventLoopFuture<[Database]> {
        let query = ListDatabases()
        return self.getConnection(writable: false).then { connection in
            return query.execute(on: connection.implicitSession).map { descriptions in
                return descriptions.map { description in
                    return self[description.name]
                }
            }
        }
    }
}
