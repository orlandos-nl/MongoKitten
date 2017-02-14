//
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
    
    #if Xcode
    static var codecov: Bool {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/../../codecov"
        return FileManager.default.fileExists(atPath: path)
    }
    #else
        static var codecov: Bool {
            guard let out = getenv("mongokittencodecov") else { return false }
            
            guard let s = String(validatingUTF8: out) else {
                return false
            }
            
            return s.lowercased().contains("true")
        }
    #endif
    
    static var mongoURL: String {
        let defaultURL = "mongodb://localhost:27017/mongokitten-unittest?appname=xctest"
        
        guard let out = getenv("mongokittentest") else { return defaultURL }
        return String(validatingUTF8: out) ?? defaultURL
    }
    
    private static var db: Database = try! Database(mongoURL: mongoURL)
    
    static var dbs: [Database] {
        var databases = [db]
        if let codecovDb = codecovDb {
            databases.append(codecovDb)
        }
        
        return databases
    }
    
    private static var codecovDb: Database? = {
        return codecov ? try! Database(mongoURL: "mongodb://localhost:27018/mongokitten-unittest?appname=xctest") : nil
    }()
    
    static var testingUsers = [Document]()
    
    static func clean() throws {
        for db in dbs {
            // Erase the testing database:
            for aCollection in try db.listCollections() where !aCollection.name.contains("system") && aCollection.name != "zips" && aCollection.name != "restaurants" {
                try aCollection.drop()
            }
            
            // Validate zips count
            if try db["zips"].count() != 29353 {
                throw TestError.TestDataNotPresent
            }
        }
    }
    
    static func disconnect() throws {
        try db.server.disconnect()
    }
}
