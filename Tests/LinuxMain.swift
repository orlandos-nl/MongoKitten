import XCTest
@testable import MongoKittenTests

XCTMain([
    testCase(CollectionTests.allTests),
    testCase(AdministrationCommandsTests.allTests),
    testCase(DatabaseTests.allTests),
    testCase(ClientSettingsTest.allTests),
    testCase(GeoJSONTests.allTests),
    testCase(AggregationTests.allTests),
    testCase(GridFSTest.allTests)
])
