import Async

extension Collection {
    @discardableResult
    public func remove(_ query: Query = [:]) -> Future<Int> {
        let remove = Delete.Single(matching: query, limit: .one)
        
        return self.connectionPool.retain().flatMap { connection in
            return try remove.execute(on: connection, collection: self)
        }
    }
    
    @discardableResult
    public func removeAll(_ query: Query = [:]) -> Future<Int> {
        let remove = Delete.Single(matching: query, limit: .all)
        
        return self.connectionPool.retain().flatMap { connection in
            return try remove.execute(on: connection, collection: self)
        }
    }
}
