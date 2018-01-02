import Async

extension Collection {
    @discardableResult
    public func insert(_ document: C) -> Future<Reply.Insert> {
        return insertAll([document])
    }
    
    @discardableResult
    public func insertAll(_ documents: [C]) -> Future<Reply.Insert> {
        let insert = Insert<C>(documents, into: self)
        
        return insert.execute(on: self.connection)
    }
}
