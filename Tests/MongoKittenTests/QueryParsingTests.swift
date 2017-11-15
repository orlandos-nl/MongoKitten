import XCTest
import MongoKitten

public class QueryParsingTests: XCTestCase {
    public static var allTests: [(String, (QueryParsingTests) -> () throws -> Void)] {
        return [
            
        ]
    }
    
    func expect(_ aqt: AQT, for query: Document, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(aqt, AQT(parse: query), message, file: file, line: line)
    }
    
    func testEmptyQueryParsing() {
        expect(.nothing, for: [])
    }
    
    func testOrQueryParsing() {
        expect(.or([.valEquals(key: "foo", val: 1), .valEquals(key: "bar", val: 2)]), for: [
            "$or": [
                "foo": ["$eq": 1],
                "bar": ["$eq": 2]
            ] as Document // to preserve order
            ])
    }
}
