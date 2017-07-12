extension Collection {
    /// Creates an `Index` in this `Collection` on the specified keys.
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/createIndexes/#dbcmd.createIndexes
    ///
    /// - parameter name: The name of this index used to identify it
    /// - parameter parameters: All `IndexParameter` options applied to the index
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    @available(*, deprecated: 4.0.5, message: "The index name mustn't be optional")
    public func createIndex(named name: String? = nil, withParameters parameters: IndexParameter...) throws {
        try self.createIndexes([(name: name, parameters: parameters)])
    }
    
    /// Creates multiple indexes as specified
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/createIndexes/#dbcmd.createIndexes
    ///
    /// - parameter indexes: The indexes to create. Accepts an array of tuples (each tuple representing an Index) which an contain a name and always contains an array of `IndexParameter`.
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    @available(*, deprecated: 4.0.5, message: "Index names mustn't be optional")
    public func createIndexes(_ indexes: [(name: String?, parameters: [IndexParameter])]) throws {
        guard let wireVersion = database.server.serverData?.maxWireVersion , wireVersion >= 2 else {
            throw MongoError.unsupportedOperations
        }
        
        var indexDocs = [Document]()
        
        for index in indexes {
            var indexDocument: Document = [
                "name": index.name
            ]
            
            for parameter in index.parameters {
                indexDocument += parameter.document
            }
            
            indexDocs.append(indexDocument)
        }
        
        let document = try firstDocument(in: try database.execute(command: ["createIndexes": self.name, "indexes": Document(array: indexDocs)]).await())
        
        guard Int(document["ok"]) == 1 else {
            throw MongoError.commandFailure(error: document)
        }
    }
    
    /// Removes all `Document`s matching the `filter` until the `limit` is reached
    ///
    /// TODO: Better docs
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/delete/#dbcmd.delete
    ///
    /// - parameter removals: A list of filters to match documents against. Any given filter can be used infinite amount of removals if `0` or otherwise as often as specified in the limit
    /// - parameter writeConcern: The `WriteConcern` used for this operation
    /// - parameter stoppingOnError: If true, stop removing when one operation fails - defaults to true
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    @available(*, deprecated: 4.1.0, message: "Limit must be .one or .all")
    @discardableResult
    public func remove(bulk removals: [(filter: Query, limit: Int)], writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        let removals = removals.map { filter, limit -> (Query, RemoveLimit) in
            (filter, limit == 0 ? RemoveLimit.all : RemoveLimit.one)
        }
        
        return try self.remove(bulk: removals, writeConcern: writeConcern, stoppingOnError: ordered)
    }
    
    /// Removes `Document`s matching the `filter` until the `limit` is reached
    ///
    /// TODO: Better docs
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/delete/#dbcmd.delete
    ///
    /// - parameter filter: The QueryBuilder filter to use when finding Documents that are going to be removed
    /// - parameter limit: The amount of times this filter can be used to find and remove a Document (0 is every document)
    /// - parameter ordered: If true, stop removing when one operation fails - defaults to true
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    @available(*, deprecated: 4.1.0, message: "Limit must be .one or .all")
    @discardableResult
    public func remove(_ filter: Query? = [:], limitedTo limit: Int, writeConcern: WriteConcern? = nil, stoppingOnError ordered: Bool? = nil) throws -> Int {
        return try self.remove(filter, limitedTo: limit == 0 ? .all : .one, writeConcern: writeConcern, stoppingOnError: ordered)
    }
}
