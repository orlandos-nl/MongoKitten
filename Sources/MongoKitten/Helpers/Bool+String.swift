//
//  Bool+StringLiteral.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 06/01/2017.
//
//

import Foundation

extension Bool {
    init(string value:String) {
        switch value.lowercased() {
        case "true":
            self = true
        case "false":
            self = false
        default:
            self = false
        }
    }
}
