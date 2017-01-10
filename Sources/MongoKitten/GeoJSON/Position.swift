//
//  Position.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation


/// A representation of a GeoJSON Position.
/// 
public struct Position {

    public let values: [Double]

    /// The GeoJSON Position.
    ///
    /// - Parameter values: positions at least 2.
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
        // DJB2 Algorithm
        return self.values.reduce(5381) {
            ($0 << 5) &+ $0 &+ $1.hashValue
        }
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

