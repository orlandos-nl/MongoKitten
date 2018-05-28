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
    }
    
    func testPipeline() throws {
        let pets = try connection.then { connection -> EventLoopFuture<Int> in
            let pets = connection["test"]["pets"]
            
            // TODO: Real pet names?
            let a = pets.addPet(named: "A", owner: "Joannis")
            let b = pets.addPet(named: "B", owner: "Joannis")
            let c = pets.addPet(named: "C", owner: "Robbert")
            let d = pets.addPet(named: "D", owner: "Robbert")
            let e = pets.addPet(named: "E", owner: "Henk")
            let f = pets.addPet(named: "F", owner: "Piet")
            
            let inserts = a.and(b).and(c).and(d).and(e).and(f)
            
            return inserts.then { _ in
                do {
                    let query: Query = "owner" == "Joannis" || "owner" == "Robbert"
                    let pipeline = try Pipeline().match(query).count(writingInto: "pets")
                    
                    return pets.aggregate(pipeline)
                } catch {
                    return connection.eventLoop.newFailedFuture(error: error)
                }
            }
        }.wait()
        
        XCTAssertEqual(pets, 4)
    }
}

extension MongoCollection {
    func addPet(named name: String, owner: String) -> EventLoopFuture<Void> {
        return self.insert([
            "_id": self.objectIdGenerator.generate(),
            "name": name,
            "owner": owner
        ]).map { _ in }
    }
}
