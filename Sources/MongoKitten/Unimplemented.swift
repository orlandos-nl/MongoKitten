//
//  Unimplemented.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 24-05-18.
//

import Foundation

func unimplemented(function: String = #function) -> Never {
    fatalError("\(function) is unimplemented")
}
