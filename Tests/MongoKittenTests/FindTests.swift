import NIO
import MongoKitten
import XCTest

class FindTests : XCTestCase {
    let group = MultiThreadedEventLoopGroup(numThreads: 1)
    let settings = try! ConnectionSettings("mongodb://localhost:27017")
    var connection: EventLoopFuture<MongoDBConnection>!
    
    override func setUp() {
        self.connection = MongoDBConnection.connect(on: group, settings: settings)
        
        try! self.connection.then { connection in
            return connection["test"].drop()
        }.wait()
    }
    
    func createTestData(n: Int, in collection: MongoCollection) -> EventLoopFuture<Void> {
        func nextDocument() -> Document {
            return [
                "_id": collection.objectIdGenerator.generate()
            ]
        }
        
        var future = collection.insert(nextDocument())
        
        for _ in 1..<n {
            future = future.then { _ in
                return collection.insert(nextDocument())
            }
        }
        
        return future.map { _ in }
    }
    
    func testFind() throws {
        do {
            var n = 152
            
            try connection.then { connection -> EventLoopFuture<Cursor<Document>> in
                let collection = connection["test"]["test"]
                
                return self.createTestData(n: n, in: collection).then {
                    return collection.find()
                }
            }.then { cursor -> EventLoopFuture<Void> in
                let future = cursor.forEach { doc in
                    n -= 1
                }
                
                future.whenSuccess {
                    XCTAssertEqual(n, 0, "The amount of inserts did not match the found results")
                }
                
                return future
            }.wait()
        } catch {
            print(error)
            throw error
        }
    }
}
