//
//  GeoJSONError.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 10/01/2017.
//
//

import Foundation


/// GeoJSON Error
///
/// - positionMustContainTwoOrMoreElements: `Position` must contain at least two elements
/// - coordinatesMustContainTwoOrMoreElements: Coordinates must contain at least two `Position`
/// - firstAndLastPositionMustBeTheSame: First and Last `Position` must be the same
/// - ringMustContainFourOrMoreElements: Ring must containa at least four `Position`
public enum GeoJSONError: Error {
    case positionMustContainTwoOrMoreElements
    case coordinatesMustContainTwoOrMoreElements
    case firstAndLastPositionMustBeTheSame
    case ringMustContainFourOrMoreElements
}
