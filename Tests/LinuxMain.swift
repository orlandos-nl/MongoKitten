import XCTest
@testable import MongoKittenTests

XCTMain([
    testCase(AdministrationCommandsTests.allTests),
    testCase(AggregationTests.allTests),
    testCase(ClientSettingsTest.allTests),
    testCase(CollectionTests.allTests),    
    testCase(DatabaseTests.allTests),
    testCase(GridFSTest.allTests),
    testCase(GeoJSONTests.allTests),
    testCase(HelperObjectTests.allTests),
    testCase(InternalTests.allTests),
    testCase(SetupTests.allTests)    
])
