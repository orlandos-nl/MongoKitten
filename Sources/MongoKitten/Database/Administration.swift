//
//  Administration.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 31/12/2016.
//
//

import Foundation

public protocol Administration {
    func createCollection(named name: String, options: Document?) throws
    func drop() throws
    func copy(toDatabase database: String, asUser user: (user: String, nonce: String, password: String)?) throws
    func clone(toNamespace ns: String, fromServer server: String, filteredBy filter: Query?) throws
    func clone(toNamespace ns: String, fromServer server: String, filteredBy filter: Document?) throws
    func clone(collection instance: Collection, toCappedCollectionNamed otherCollection: String, cappedTo capped: Int32) throws
}
