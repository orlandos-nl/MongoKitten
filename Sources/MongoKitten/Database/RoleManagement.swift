//
//  RoleManagement.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 28/12/2016.
//
//

import Foundation

public protocol RoleManagement {
    func grant(roles roleList: Document, to user: String) throws
}
