
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import MongoKitten
import BSON
import Foundation

final class TestManager {
    enum TestError : Error {
        case TestDataNotPresent
    }
    
    static var mongoURL: String {
        let defaultURL = "mongodb://localhost/mongokitten-unittest?appname=xctest"
        
        guard let out = getenv("mongokittentest") else { return defaultURL }
        return String(validatingUTF8: out) ?? defaultURL
    }
    
    static var db: Database = try! Database(mongoURL)
    
    static func disconnect() throws {
        // TODO: Fix Linux constant disconnects
        #if !os(Linux)
        try db.server.disconnect()
        #endif
    }
}

