//
//  Position.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation


public struct Position {

    public let values: [Double]

    ///
    ///
    /// - Parameter values: positions
    /// - Throws: GeoJSONError
    public init(values: [Double]) throws {
        guard values.count >= 2 else { throw GeoJSONError.positionMustContainTwoOrMoreElements }
        self.values = values
    }

    public init(first: Double, second: Double, remaining: Double...) {
        var vals = [Double]()
        vals.append(first)
        vals.append(second)

        for current in remaining {
            vals.append(current)
        }

        self.values = vals
    }
}

extension Position: Hashable {

    public static func == (lhs: Position, rhs: Position) -> Bool {
        return lhs.values == rhs.values
    }


    public var hashValue: Int {
        var value = 0

        for current in values {
            value = current.hashValue + value
        }

        return value
    }
}

extension Position: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "Position { values = \(values.description) }"
    }

    public var debugDescription: String {
        return "Position { values = \(values.debugDescription) }"
    }
}

