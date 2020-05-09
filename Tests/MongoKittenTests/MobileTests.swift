import MongoKitten
import NIO
import XCTest

let loop = MultiThreadedEventLoopGroup(numberOfThreads: 1)

class CRUDTests : XCTestCase {
    let settings = try! ConnectionSettings("mongodb://localhost:27017")
    var db: MongoCluster!

    override func setUp() {
        db = try! MongoCluster.connect(on: loop, settings: settings).wait()
    }
    
    func testListDatabases() throws {
        let databases = try db.listDatabases().wait()
        XCTAssertTrue(databases.contains { $0.name == "admin" })
        
        for db in databases {
            XCTAssertNoThrow(try db.listCollections().wait())
        }
    }

    func testInsert() {
        
    }
}
