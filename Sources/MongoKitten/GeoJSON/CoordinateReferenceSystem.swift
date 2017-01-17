//
//  CoordinateReferenceSystem.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 13/01/2017.
//
//

import Foundation

/// A GeoJSon Coordinate Reference System (CRS).
public struct CoordinateReferenceSystem {


    /// The type of this Coordinate Reference System.
    let typeName: String


    public init(typeName: String) {
        self.typeName = typeName
    }
}


extension CoordinateReferenceSystem: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        return ["type": "name", "properties": ["name": self.typeName] as Document] as Document
    }
}
