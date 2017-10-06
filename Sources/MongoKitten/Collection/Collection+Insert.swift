import Async

extension Collection {
    @discardableResult
    public func insert(_ document: Document) throws -> Future<Reply.Insert> {
        return try insertAll([document])
    }
    
    @discardableResult
    public func insertAll(_ documents: [Document]) throws -> Future<Reply.Insert> {
        let insert = Insert(documents, into: self)
        return try insert.execute(on: database)
    }
}
