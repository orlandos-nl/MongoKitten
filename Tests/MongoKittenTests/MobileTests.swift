import MongoKitten
import NIO
import XCTest

#if canImport(NIOTransportServices)
import NIOTransportServices
let loop = NIOTSEventLoopGroup(loopCount: 1, defaultQoS: .default).next()
#else
let loop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
#endif

class CRUDTests : XCTestCase {
    let settings = try! ConnectionSettings("mongodb://localhost:27017")
    var db: MongoConnection!

    override func setUp() {
        db = try! MongoConnection.connect(settings: settings, on: loop).wait()
    }
    
    func testListDatabases() throws {
        try XCTAssertTrue(db.listDatabases().wait().contains { $0.name == "admin" })
    }

    func testInsert() {
        
    }
}
