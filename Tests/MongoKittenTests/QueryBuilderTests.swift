import XCTest
import MongoKitten

public class QueryBuilderTests: XCTestCase {
    public static var allTests: [(String, (QueryBuilderTests) -> () throws -> Void)] {
        return [
            ("testOrOperator", testOrOperator),
            ("testAndOperator", testAndOperator),
        ]
    }
    
    func expect(_ doc: Document, for query: Query, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(doc, query.queryDocument, message, file: file, line: line)
    }
    
    func testOrOperator() {
        let foo1: Query = "foo" == 1
        let foo2: Query = "bar" == 2
        let expectation: Document = [
            "$or": [
                foo1.queryDocument,
                foo2.queryDocument
            ]
        ]
        
        expect(expectation, for: foo1 || foo2)
        expect(expectation, for: Query() || foo1 || foo2, "Empty query should match nothing")
    }
    
    func testAndOperator() {
        let foo1: Query = "foo" == 1
        let foo2: Query = "bar" == 2
        let expectation: Document = [
            "$and": [
                foo1.queryDocument,
                foo2.queryDocument
            ]
        ]
        
        expect(expectation, for: foo1 && foo2)
        expect(expectation, for: Query() && foo1 && foo2, "Empty query should match nothing")
    }
}
