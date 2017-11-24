
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Async
import MongoKitten
import BSON
import Dispatch
import Foundation

final class TestManager {
    enum TestError : Error {
        case TestDataNotPresent
    }
    
    static var mongoURL: (host: String, database: String) {
        let defaultURL = "mongodb://localhost:27017/mongokitten-unittest"
        
        guard let out = getenv("mongokittentest") else { return (defaultURL, "mongokitten-unittest") }
        return (String(validatingUTF8: out) ?? defaultURL, "mongokitten-unittest")
    }
    
    static var db = try! Database.connect(server: "mongodb://localhost", database: "mongokitte-unittest", worker: DispatchQueue(label: "test")).blockingAwait(timeout: .seconds(5))
}

