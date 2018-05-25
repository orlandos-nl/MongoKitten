import NIO
import Foundation

let group = MultiThreadedEventLoopGroup(numThreads: 1)

let connection = try MongoDBConnection.connect(on: group)

struct MyUser: Codable {
    var _id = ObjectId()
    var name: String
    
    init(named name: String) {
        self.name = name
    }
}

try connection.then { connection -> EventLoopFuture<Collection> in
    let collection = connection["test"]["test"]
    
    let user = MyUser(named: "piet")
    let doc = try! BSONEncoder().encode(user)
    
    let future = collection.insert(doc)
    
    future.whenSuccess { reply in
        print(reply)
    }
    
    return future.map { _ in
        return collection
    }
}.then { collection -> EventLoopFuture<Collection> in
    let future = collection.count()
    
    future.whenSuccess { count in
        print("count", count)
    }
    
    return future.map { _ in
        return collection
    }
}.then { collection -> EventLoopFuture<Collection> in
    let future = collection.update(
        "name" == "piet",
        setting: [
            "name": "henk"
        ]
    )
    
    future.whenSuccess { removed in
        print("updated", removed)
    }
    
    return future.map { _ in
        return collection
    }
}.then { collection -> EventLoopFuture<Collection> in
    let future = collection.delete("name" == "kaas")
    
    future.whenSuccess { removed in
        print("removed", removed)
    }
    
    return future.map { _ in
        return collection
    }
}.then { collection -> EventLoopFuture<Collection> in
    let future = collection.count()
    
    future.whenSuccess { count in
        print("count", count)
    }
    
    return future.map { _ in
        return collection
    }
}.wait()
