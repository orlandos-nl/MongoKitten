//
//  TestManager.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 01-03-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import MongoKitten
import BSON
import Foundation

final class TestManager {
    enum TestError : ErrorProtocol {
        case TestDataNotPresent
    }
    
    static var server = try! Server(at: "localhost", using: (username: "mongokitten-unittest-user", password: "mongokitten-unittest-password"), automatically: false)
    static var db: Database { return server["mongokitten-unittest"] }
    static let wcol = db["wcol"]
    
    static var testingUsers = [Document]()
    
    static func connect() throws {
        if server.isConnected == false {
            try server.connect()
        }
    }
    
    static func clean() throws {
        // Erase the testing database:
        for aCollection in try db.getCollections() {
            #if os(Linux)
                if !aCollection.name.containsString("system") && aCollection.name != "zips" {
                    try aCollection.drop()
                }
            #else
                if !aCollection.name.contains("system") && aCollection.name != "zips" {
                    try aCollection.drop()
                }
            #endif
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