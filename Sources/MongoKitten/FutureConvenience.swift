// Generated using Sourcery 0.15.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


// Provides convenience access to methods on Futures
// To regenerate: run the './Codegen.sh' script. This requires Sourcery to be installed.

import NIO

public protocol FutureConvenienceCallable {}

extension EventLoopFuture where T == Collection {

    /// Convenience accessor that calls findOne(_:as:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.findOne(_:as:)`
    public func findOne<D: Decodable>(_ query: Query = [:], as type: D.Type) -> EventLoopFuture<D?> {
        return self.then { collection in
            return collection.findOne(query,as: type)
        }
    }

    /// Convenience accessor that calls findOne(_:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.findOne(_:)`
    public func findOne(_ query: Query = [:]) -> EventLoopFuture<Document?> {
        return self.then { collection in
            return collection.findOne(query)
        }
    }

    /// Convenience accessor that calls count(_:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.count(_:)`
    public func count(_ query: Query? = nil) -> EventLoopFuture<Int> {
        return self.then { collection in
            return collection.count(query)
        }
    }

    /// Convenience accessor that calls distinct(onKey:where:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.distinct(onKey:where:)`
    public func distinct(onKey key: String, where filter: Query? = nil) -> EventLoopFuture<[Primitive]> {
        return self.then { collection in
            return collection.distinct(onKey: key,where: filter)
        }
    }

    /// Convenience accessor that calls insert(_:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.insert(_:)`
    public func insert(_ document: Document) -> EventLoopFuture<InsertReply> {
        return self.then { collection in
            return collection.insert(document)
        }
    }

    /// Convenience accessor that calls insert(documents:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.insert(documents:)`
    public func insert(documents: [Document]) -> EventLoopFuture<InsertReply> {
        return self.then { collection in
            return collection.insert(documents: documents)
        }
    }

    /// Convenience accessor that calls deleteAll(where:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.deleteAll(where:)`
    public func deleteAll(where query: Query) -> EventLoopFuture<Int> {
        return self.then { collection in
            return collection.deleteAll(where: query)
        }
    }

    /// Convenience accessor that calls deleteOne(where:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.deleteOne(where:)`
    public func deleteOne(where query: Query) -> EventLoopFuture<Int> {
        return self.then { collection in
            return collection.deleteOne(where: query)
        }
    }

    /// Convenience accessor that calls update(where:to:multiple:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.update(where:to:multiple:)`
    public func update(where query: Query, to document: Document, multiple: Bool? = nil) -> EventLoopFuture<UpdateReply> {
        return self.then { collection in
            return collection.update(where: query,to: document,multiple: multiple)
        }
    }

    /// Convenience accessor that calls upsert(where:to:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.upsert(where:to:)`
    public func upsert(where query: Query, to document: Document) -> EventLoopFuture<UpdateReply> {
        return self.then { collection in
            return collection.upsert(where: query,to: document)
        }
    }

    /// Convenience accessor that calls update(where:setting:multiple:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.update(where:setting:multiple:)`
    public func update(where query: Query, setting set: [String: Primitive?], multiple: Bool? = nil) -> EventLoopFuture<UpdateReply> {
        return self.then { collection in
            return collection.update(where: query,setting: set,multiple: multiple)
        }
    }

    /// Convenience accessor that calls drop on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.drop`
    public func drop() -> EventLoopFuture<Void> {
        return self.then { collection in
            return collection.drop()
        }
    }

    /// Convenience accessor that calls watch(withOptions:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.watch(withOptions:)`
    public func watch(withOptions options: ChangeStreamOptions = ChangeStreamOptions()) -> EventLoopFuture<ChangeStream<ChangeStreamNotification<Document?>>> {
        return self.then { collection in
            return collection.watch(withOptions: options)
        }
    }

}

public extension EventLoopFuture where T == Database {

    /// Convenience accessor that calls drop on the database after the future has completed.
    ///
    /// For documentation on this method, refer to `Database.drop`
    public func drop() -> EventLoopFuture<Void> {
        return self.then { database in
            return database.drop()
        }
    }

    /// Convenience accessor that calls listCollections on the database after the future has completed.
    ///
    /// For documentation on this method, refer to `Database.listCollections`
    public func listCollections() -> EventLoopFuture<[Collection]> {
        return self.then { database in
            return database.listCollections()
        }
    }

}

public extension EventLoopFuture where T == TransactionCollection {

    /// Convenience accessor that calls commit on the transactioncollection after the future has completed.
    ///
    /// For documentation on this method, refer to `TransactionCollection.commit`
    public func commit() -> EventLoopFuture<Void> {
        return self.then { transactioncollection in
            return transactioncollection.commit()
        }
    }

    /// Convenience accessor that calls abort on the transactioncollection after the future has completed.
    ///
    /// For documentation on this method, refer to `TransactionCollection.abort`
    public func abort() -> EventLoopFuture<Void> {
        return self.then { transactioncollection in
            return transactioncollection.abort()
        }
    }

}

public extension EventLoopFuture where T == TransactionDatabase {

}

public extension EventLoopFuture where T == Database {
    public subscript(collection: String) -> EventLoopFuture<MongoKitten.Collection> {
        return self.map { $0[collection] }
    }
}
