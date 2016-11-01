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
    
    static var server = try! Server(hostname: "127.0.0.1")
    static var db: Database { return server["mongokitten-unittest"] }
    static let wcol = db["wcol"]
    
    static var testingUsers = [Document]()
    
    static func connect() throws {
        if !server.isConnected {
            try server.connect()
        }
    }
    
    static func clean() throws {
        // Erase the testing database:
        for aCollection in try db.listCollections() where !aCollection.name.contains("system") && aCollection.name != "zips" {
            try aCollection.drop()
        }
        
        // Validate zips count
        if try db["zips"].count() != 29353 {
            throw TestError.TestDataNotPresent
        }
    }
    
    static func disconnect() throws {
        try server.disconnect()
    }
}
