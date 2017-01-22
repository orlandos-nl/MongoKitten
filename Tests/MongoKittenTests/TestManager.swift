//
//  TestManager.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 01-03-16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import MongoKitten
import BSON
import Foundation

final class TestManager {
    enum TestError : Error {
        case TestDataNotPresent
    }
    
    static var codecov: Bool {
        guard let out = getenv("mongokittencodecov") else { return false }
        
        guard let s = String(validatingUTF8: out) else {
            return false
        }
        
        return s.lowercased().contains("true")
    }
    
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
    
    private static weak var codecovDb: Database? = {
        return codecov ? try! Database(mongoURL: "mongodb://localhost:27018/mongokitten-unittest?appname=xctest") : nil
    }()
    
    static var testingUsers = [Document]()
    
    static func clean() throws {
        // Erase the testing database:
        for aCollection in try db.listCollections() where !aCollection.name.contains("system") && aCollection.name != "zips" && aCollection.name != "restaurants" {
            try aCollection.drop()
        }
        
        // Validate zips count
        if try db["zips"].count() != 29353 {
            throw TestError.TestDataNotPresent
        }
    }
    
    static func disconnect() throws {
        try db.server.disconnect()
    }
}
