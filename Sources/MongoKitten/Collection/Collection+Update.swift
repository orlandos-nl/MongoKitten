import Async

extension Collection {
    @discardableResult
    public func update(_ query: Query, to document: Document) throws -> Future<Reply.Update> {
        return try Update.Single(matching: query, to: document).execute(on: self)
    }
    
    @discardableResult
    public func upsert(_ query: Query, to document: Document) throws -> Future<Reply.Update> {
        var update = Update.Single(matching: query, to: document)
        update.upsert = true
        
        return try update.execute(on: self)
    }
    
    @discardableResult
    public func updateAll(_ query: Query, to document: Document) throws -> Future<Reply.Update> {
        return try Update.Single(matching: query, to: document).execute(on: self)
    }
}
