public final class TransactionCollecion: Collection {
    internal init(collection: Collection, session: ClientSession) {
        super.init(named: collection.name, in: collection.database)
        self.session = session
    }
}
