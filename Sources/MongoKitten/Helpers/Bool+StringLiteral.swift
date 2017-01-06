//
//  Bool+StringLiteral.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 06/01/2017.
//
//

import Foundation

extension Bool: ExpressibleByStringLiteral {

    public init(unicodeScalarLiteral value: String) {
        switch value.lowercased() {
        case "true":
            self = true
        case "false":
            self = false
        default:
            self = false
        }
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        switch value.lowercased() {
        case "true":
            self = true
        case "false":
            self = false
        default:
            self = false
        }
    }

    public init(stringLiteral value:String) {
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
