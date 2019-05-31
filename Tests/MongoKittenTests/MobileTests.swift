import MongoKitten
import XCTest

#if os(iOS)
class EmbeddedDatabaseCRUDTests : XCTestCase {
    var db: MobileDatabase!

    override func setUp() {
        db = MobileDatabase(settings: MobileConfiguration())
    }

    func testInsert() {
        
    }
}
#endif
