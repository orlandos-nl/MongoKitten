//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of Swift project authors
//

import XCTest
@testable import MongoKittenTests

XCTMain([
    testCase(AdministrationCommandsTests.allTests),
    testCase(AggregationTests.allTests),
    testCase(AuthenticationTests.allTests),        
    testCase(ClientSettingsTest.allTests),
    testCase(CollectionTests.allTests),    
    testCase(DatabaseTests.allTests),
    testCase(GeoJSONTests.allTests),
    testCase(GeospatialQueryingTest.allTests),
    testCase(GridFSTest.allTests),  
    testCase(HelperObjectTests.allTests),    
    testCase(InternalTests.allTests),
    testCase(SetupTests.allTests)    
])
