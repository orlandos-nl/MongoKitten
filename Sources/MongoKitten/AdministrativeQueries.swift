import NIO

extension Cluster {
    /// Lists all databases within this cluster as a MongoKitten Database
    ///
    /// This includes the adminsitrative database(s)
    public func listDatabases() -> EventLoopFuture<[Database]> {
        let query = ListDatabases()
        let collection = self[query.namespace.databaseName][query.namespace.collectionName]
        
        return query.execute(on: collection).map { descriptions in
            return descriptions.map { description in
                return self[description.name]
            }
        }
    }
}
