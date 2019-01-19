import NIO

extension Cluster {
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
