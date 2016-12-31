//
//  UserManagement.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 28/12/2016.
//
//

import Foundation


public protocol UserManagement {
    func createUser(_ user: String, password: String, roles: Document, customData: Document?) throws
    func update(user username: String, password: String, roles: Document, customData: Document?) throws
    func drop(user username: String) throws
    func dropAllUsers() throws
 
}
