struct MongoKittenError: Error {
    enum Kind {
        case unsupportedFeatureByServer
        
        case cannotConnect
        
        case invalidGridFSChunk
    }

    enum Reason {
        case cursorClosed

        case noTargetDatabaseSpecified
        
        case transactionForUnsupportedQuery
    }

    let kind: Kind
    let reason: Reason?

    init(_ kind: Kind, reason: Reason?) {
        self.kind = kind
        self.reason = reason
    }
}
