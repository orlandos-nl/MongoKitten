import Async

extension Collection {
    @discardableResult
    public func remove(_ query: Query = [:]) -> Future<Int> {
        let remove = Delete.Single(matching: query, limit: .one)
        
        return remove.execute(on: self.connection, collection: self)
    }
    
    @discardableResult
    public func removeAll(_ query: Query = [:]) -> Future<Int> {
        let remove = Delete.Single(matching: query, limit: .all)
        
        return remove.execute(on: self.connection, collection: self)
    }
}
