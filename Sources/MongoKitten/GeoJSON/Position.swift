//
//  Position.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 07/01/2017.
//
//

import Foundation

/// A position with longitude and latitude.
public struct Position {
    /// The geo location
    public let location: (longitude: Double, latitude: Double)

    /// Creates a position on a geo 2d sphere
    public init(values: (longitude: Double, latitude: Double)) {
        self.location = values
    }
}

/// Makes positions equatable
extension Position: Hashable {
    /// Checks if two positions are at the same location 
    public static func == (lhs: Position, rhs: Position) -> Bool {
        return lhs.location == rhs.location
    }

    /// A hash value for comparing
    public var hashValue: Int {
        return Int(location.longitude + location.latitude)
    }
}

extension Position: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "Position { longitude: \(location.longitude), latitude: \(location.latitude) }"
    }

    public var debugDescription: String {
        return "Position { longitude: \(location.longitude), latitude: \(location.latitude) }"
    }
}

