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


/// GeoJSON Error
///
/// - positionMustContainTwoOrMoreElements: `Position` must contain at least two elements
/// - coordinatesMustContainTwoOrMoreElements: Coordinates must contain at least two `Position`
/// - firstAndLastPositionMustBeTheSame: First and Last `Position` must be the same
/// - ringMustContainFourOrMoreElements: Ring must containa at least four `Position`
public enum GeoJSONError: Error {
    /// -
    case positionMustContainTwoOrMoreElements
    
    /// -
    case coordinatesMustContainTwoOrMoreElements
    
    /// -
    case firstAndLastPositionMustBeTheSame
    
    /// - 
    case ringMustContainFourOrMoreElements
}
