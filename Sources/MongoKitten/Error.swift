struct MongoKittenError: Error {
    enum Kind {
        case unsupportedFeatureByServer
        
        case cannotConnect
    }

    enum Reason {
        case cursorClosed

        case noTargetDatabaseSpecified
    }

    let kind: Kind
    let reason: Reason?

    init(_ kind: Kind, reason: Reason?) {
        self.kind = kind
        self.reason = reason
    }
}
