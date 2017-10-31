import Async

extension Collection {
    @discardableResult
    public func insert(_ document: Document) -> Future<Reply.Insert> {
        return insertAll([document])
    }
    
    @discardableResult
    public func insertAll(_ documents: [Document]) -> Future<Reply.Insert> {
        let insert = Insert(documents, into: self)
        
        return connectionPool.retain().flatten(insert.execute)
    }
}
