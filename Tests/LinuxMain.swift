import XCTest
@testable import MongoKittenTestSuite

XCTMain([
    testCase(CollectionTests.allTests),
    testCase(AdministrationCommandsTests.allTests),
    testCase(DatabaseTests.allTests)
])
