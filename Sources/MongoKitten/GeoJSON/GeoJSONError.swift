//
//  GeoJSONError.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 10/01/2017.
//
//

import Foundation


public enum GeoJSONError: Error {
    case positionMustContainTwoOrMoreElements
    case coordinatesMustContainTwoOrMoreElements
    case firstAndLastPositionMustBeTheSame
    case ringMustContainFourOrMoreElements
}
