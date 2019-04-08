//
//  AppDelegate.swift
//  MongoKittenExample
//
//  Created by Joannis Orlandos on 23/03/2019.
//  Copyright © 2019 Joannis Orlandos. All rights reserved.
//

import UIKit
import MongoKitten

let mongoDB = try! MobileDatabase(settings: .default())
let database = mongoDB["demo"]

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let users = database["users"]

        if try! users.count().wait() == 0 {
            let encoder = BSONEncoder()

            func insert<C: Codable>(_ entity: C) throws {
                _ = try users.insert(encoder.encode(entity)).wait()
            }

            try! insert(User(named: "Joannis Orlandos"))
            try! insert(User(named: "Robbert Brandsma"))
        }
        // Override point for customization after application launch.
        return true
    }
}

