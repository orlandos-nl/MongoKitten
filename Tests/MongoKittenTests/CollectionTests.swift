import MongoKitten
import NIO
import XCTest

final class SuperTest: XCTestCase {
    func testInsert() throws {
        let group = MultiThreadedEventLoopGroup(numThreads: 1).next()
        
        let connection = try MongoDBConnection.connect(on: group)
        connection.thenThrowing { connection -> Void in
            let doc: Document = [
                "_id": ObjectId(),
                "hello": 3
            ]
            let insert = Insert([doc], into: "test.test")
            try insert.execute(on: connection)
        }
    }
}
