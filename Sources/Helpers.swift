//
//  Helpers.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 14-04-16.
//  Copyright © 2016 OpenKitten. All rights reserved.
//

import Foundation

/// Gets all documents from a reply and throws if it's not a reply
/// - parameter in: The message in which we'll find the documents
/// - returns: The first found document
@warn_unused_result
internal func firstDocument(in message: Message) throws -> Document {
    let documents = try allDocuments(in: message)
    
    guard let document = documents.first else {
        throw InternalMongoError.incorrectReply(reply: message)
    }
    
    return document
}

/// Gets all documents from a reply and throws if it's not a reply
/// - parameter in: The message in which we'll find the documents
/// - returns: The documents
@warn_unused_result
internal func allDocuments(in message: Message) throws -> [Document] {
    guard case .Reply(_, _, _, _, _, _, let documents) = message else {
        throw InternalMongoError.incorrectReply(reply: message)
    }
    
    return documents
}

postfix operator * {}

/// Will convert an ArraySlice<Byte> to [Byte]
internal postfix func * (slice: ArraySlice<Byte>) -> [Byte] {
    return Array(slice)
}

/// Replaces occurrences of data with new data in a string
/// Because "having a single cross-platform API for a programming language is stupid"
/// TODO: Remove/update with the next Swift version
internal func replaceOccurrences(in string: String, where matching: String, with replacement: String) -> String {
    return string.replacingOccurrences(of: matching, with: replacement)
}

protocol WeakProtocol {
    associatedtype Element : AnyObject
    weak var value: Element? { get set }
}

struct Weak<Element : AnyObject> : WeakProtocol {
    weak var value: Element?
    init(_ v: Element) {
        self.value = v
    }
}

extension Dictionary where Value : WeakProtocol {
    /// Removes deallocated weak values
    mutating func clean() {
        for (key, value) in self {
            if value.value == nil {
                self.removeValue(forKey: key)
            }
        }
    }
}

extension Array where Element : WeakProtocol {
    /// Removes deallocated weak values
    mutating func clean() {
        for (index, value) in self.enumerated() {
            if value.value == nil {
                self.remove(at: index)
            }
        }
    }
}
