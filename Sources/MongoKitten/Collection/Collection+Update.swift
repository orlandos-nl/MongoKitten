import Async

extension Collection {
    @discardableResult
    public func update(_ query: Query, to document: Document) -> Future<Reply.Update> {
        let update = Update<C>.Single(matching: query, to: document)
        
        return update.execute(on: self.connection, collection: self)
    }
    
    @discardableResult
    public func upsert(_ query: Query, to document: Document) -> Future<Reply.Update> {
        var update = Update<C>.Single(matching: query, to: document)
        update.upsert = true
        
        return update.execute(on: self.connection, collection: self)
    }
    
    @discardableResult
    public func updateAll(_ query: Query, to document: Document) -> Future<Reply.Update> {
        let update = Update<C>.Single(matching: query, to: document)
        
        return update.execute(on: self.connection, collection: self)
    }
}
