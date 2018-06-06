// Generated using Sourcery 0.11.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


// Provides convenience access to methods on Futures
// To regenerate: run the './Codegen.sh' script. This requires Sourcery to be installed.

import NIO

public protocol FutureConvenienceCallable {}

public extension EventLoopFuture where T == Collection {

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

    /// Convenience accessor that calls deleteAll(_:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.deleteAll(_:)`
    public func deleteAll(_ query: Query = [:]) -> EventLoopFuture<Int> {
        return self.then { collection in
            return collection.deleteAll(query)
        }
    }

    /// Convenience accessor that calls deleteOne(_:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.deleteOne(_:)`
    public func deleteOne(_ query: Query = [:]) -> EventLoopFuture<Int> {
        return self.then { collection in
            return collection.deleteOne(query)
        }
    }

    /// Convenience accessor that calls update(_:to:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.update(_:to:)`
    public func update(_ query: Query, to document: Document) -> EventLoopFuture<UpdateReply> {
        return self.then { collection in
            return collection.update(query,to: document)
        }
    }

    /// Convenience accessor that calls upsert(_:to:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.upsert(_:to:)`
    public func upsert(_ query: Query, to document: Document) -> EventLoopFuture<UpdateReply> {
        return self.then { collection in
            return collection.upsert(query,to: document)
        }
    }

    /// Convenience accessor that calls update(_:setting:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.update(_:setting:)`
    public func update(_ query: Query, setting set: [String: Primitive?]) -> EventLoopFuture<UpdateReply> {
        return self.then { collection in
            return collection.update(query,setting: set)
        }
    }

    /// Convenience accessor that calls distinct(onKey:filter:) on the collection after the future has completed.
    ///
    /// For documentation on this method, refer to `Collection.distinct(onKey:filter:)`
    public func distinct(onKey key: String, filter: Query? = nil) -> EventLoopFuture<[Primitive]> {
        return self.then { collection in
            return collection.distinct(onKey: key,filter: filter)
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

}

public extension EventLoopFuture where T == Database {
    public subscript(collection: String) -> EventLoopFuture<MongoKitten.Collection> {
        return self.map { $0[collection] }
    }
}
