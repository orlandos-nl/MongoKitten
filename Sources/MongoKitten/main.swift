import NIO
import Foundation

let group = MultiThreadedEventLoopGroup(numThreads: 1)

let connection = try MongoDBConnection.connect(on: group)

var future: EventLoopFuture<Insert<Document>.Result>?
try connection.thenThrowing { connection -> Void in
    let doc: Document = [
        "_id": ObjectId(),
        "hello": 3
    ]
    
    let collectionRef = CollectionReference(to: "test", inDatabase: "test")
    let insert = Insert([doc], into: collectionRef)
    future = try insert.execute(on: connection)
}.wait()

print(try future?.wait())
