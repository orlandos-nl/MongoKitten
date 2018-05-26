import NIO
import MongoKitten
import XCTest

class FindTests : XCTestCase {
    let group = MultiThreadedEventLoopGroup(numThreads: 1)
    let settings = try! ConnectionSettings("mongodb://localhost:27017")
    var connection: EventLoopFuture<MongoDBConnection>!
    
    override func setUp() {
        self.connection = MongoDBConnection.connect(on: group, settings: settings)
    }
    
    func testFind() throws {
        do {
            try connection.then { connection in
                return connection["test"]["test"].find()
            }.then { cursor in
                cursor.forEach { doc in
                    print(doc)
                }
            }.wait()
        } catch {
            print(error)
            throw error
        }
    }
}
