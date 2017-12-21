import Async

extension Collection {
    @discardableResult
    public func update(_ query: Query, to document: Document) -> Future<Reply.Update> {
        let update = Update.Single(matching: query, to: document)
        
        return self.connectionPool.retain().flatMap(to: Reply.Update.self) { connection in
            return update.execute(on: connection, collection: self)
        }
    }
    
    @discardableResult
    public func upsert(_ query: Query, to document: Document) -> Future<Reply.Update> {
        var update = Update.Single(matching: query, to: document)
        update.upsert = true
        
        return self.connectionPool.retain().flatMap(to: Reply.Update.self) { connection in
            return update.execute(on: connection, collection: self)
        }
    }
    
    @discardableResult
    public func updateAll(_ query: Query, to document: Document) -> Future<Reply.Update> {
        let update = Update.Single(matching: query, to: document)
        
        return self.connectionPool.retain().flatMap(to: Reply.Update.self) { connection in
            return update.execute(on: connection, collection: self)
        }
    }
}
