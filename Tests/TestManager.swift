//
//  TestManager.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 01-03-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import C7
import TCP
import MongoKitten
import BSON
import Foundation

final class TestManager {
    static let c: SocketClient = TCPStreamClient("127.0.0.1", port: 27017)
    static var serverServer = try! Server(client: c, autoConnect: true, authentication: (username: "mongokitten-unittest-user", password: "mongokitten-unittest-password"), autoConnect: false)
    static var testDatabase: Database { return server["mongokitten-unittest"] }
    static var testCollection: Collection { return testDatabase["testcol"] }
    
    static var testingUsers = [Document]()
    
    static func connect() throws {
        if !server.connected {
            try server.connect()
        }
    }
    
    static func dropAllTestingCollections() throws {
        // Erase the testing database:
        for aCollection in try! testDatabase.getCollections() {
            if !aCollection.name.containsString("system") {
                try! aCollection.drop()
            }
        }
    }
    
    static func disconnect() throws {
        try server.disconnect()
    }
    
    static func fillCollectionWithSampleUsers(randomAmountBetween amount: Range<Int> = 2..<5000) throws {
        // erase first
        try self.dropAllTestingCollections()
        testingUsers.removeAll()
        
        // generate
        for _ in 0..<Int.random(amount) {
            testingUsers.append(*[
                "name": Randoms.randomFakeName(),
                "gender": Randoms.randomFakeGender(),
                "slogan": Randoms.randomFakeConversation(),
                "registered": NSDate.randomWithinDaysBeforeToday(180)
            ])
        }
        
        // insert
        testingUsers = try testCollection.insert(testingUsers)
    }
}