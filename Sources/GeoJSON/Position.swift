//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation
import BSON

/// A representation of a GeoJSON Position.
/// 
public struct Position {
    /// Two or more 
    public let values: [Double]

    /// The GeoJSON Position.
    ///
    /// - Parameter values: positions at least 2.
    /// - Throws: GeoJSONError
    public init(values: [Double]) throws {
        guard values.count >= 2 else { throw GeoJSONError.positionMustContainTwoOrMoreElements }
        self.values = values
    }

    /// Initializes a Position using the coordinates
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
    /// Compares two positions to be equal to each other
    public static func == (lhs: Position, rhs: Position) -> Bool {
        return lhs.values == rhs.values
    }

    /// Makes a position hashable, thus usable as a key in a dictionary
    public var hashValue: Int {
        // DJB2 Algorithm
        return self.values.reduce(5381) {
            ($0 << 5) &+ $0 &+ $1.hashValue
        }
    }
}

extension Position: CustomStringConvertible, CustomDebugStringConvertible {
    /// The description or the position's text representation
    public var description: String {
        return "Position { values = \(values.description) }"
    }

    /// The debug description or the position's text representation
    public var debugDescription: String {
        return "Position { values = \(values.debugDescription) }"
    }
}

extension Position: ValueConvertible {
    /// Converts this object to an embeddable BSONPrimtive
    public func makeBSONPrimitive() -> BSONPrimitive {
        return [values[0], values[1]] as Document
    }
}
