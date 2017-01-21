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
    
    //static var server = try! Server(hostname: "localhost", port: 27017, authenticatedAs: ("mongokitten-unittest-user", "mongokitten-unittest-password", "mongokitten-unittest"))
    
    static var server: Server {
        return db.server
    }
    
    static var mongoURL: String {
        let defaultURL = "mongodb://localhost:27017/mongokitten-unittest?appname=xctest"
        
        guard let out = getenv("mongokittentest") else { return defaultURL }
        return String(validatingUTF8: out) ?? defaultURL
    }
    
    static var db: Database = try! Database(mongoURL: mongoURL)
    static let wcol = db["wcol"]
    
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
