import NIO
import MongoKitten
import XCTest

class CRUDTests : XCTestCase {
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
    
    func testUsage() throws {
        do {
            let total = 152
            var n = 0
            
            return try connection.then { connection -> EventLoopFuture<Void> in
                let collection = connection["test"]["test"]
                
                return self.createTestData(n: total, in: collection).then {
                    return collection.find()
                }.then { cursor -> EventLoopFuture<Void> in
                    let future = cursor.forEach { doc in
                        n += 1
                    }
                    
                    future.whenSuccess {
                        XCTAssertEqual(total, n, "The amount of inserts did not match the found results")
                    }
                    
                    return future
                }.then {
                    return collection.count()
                }.then { count -> EventLoopFuture<Int> in
                    XCTAssertEqual(count, 152, "The count differred from the inserts")
                    
                    return collection.deleteAll()
                }.then { deleted -> EventLoopFuture<Int> in
                    XCTAssertEqual(deleted, 152, "Not everything was deleted")
                    
                    return collection.count()
                }.map { count -> Void in
                    XCTAssertEqual(count, 0, "The count differred from the expected of 0 remaining")
                }
            }.wait()
        } catch {
            print(error)
            throw error
        }
    }
}
