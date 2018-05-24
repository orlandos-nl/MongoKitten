//
//  Error.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 24-05-18.
//

import Foundation

enum MongoKittenError : Error {
    case invalidURI(reason: String)
}
