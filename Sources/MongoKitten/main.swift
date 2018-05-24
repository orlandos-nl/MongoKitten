import NIO
import Foundation

let group = MultiThreadedEventLoopGroup(numThreads: 1)

let connection = try MongoDBConnection.connect(on: group)

try connection.thenThrowing { connection -> Void in
    let doc: Document = [
        "_id": ObjectId(),
        "hello": 3
    ]
    let insert = Insert([doc], into: "test.test")
    try insert.execute(on: connection)
}.wait()

Thread.sleep(forTimeInterval: 10)
