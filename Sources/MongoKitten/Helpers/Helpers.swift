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

/// Gets all documents from a reply and throws if it's not a reply
/// - parameter in: The message in which we'll find the documents
/// - returns: The first found document
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
internal func allDocuments(in message: Message) throws -> [Document] {
    guard case .Reply(_, _, _, _, _, _, let documents) = message else {
        throw InternalMongoError.incorrectReply(reply: message)
    }
    
    return documents
}

postfix operator *

/// Will convert an ArraySlice<Byte> to [Byte]
internal postfix func * (slice: ArraySlice<UInt8>) -> [UInt8] {
    return Array(slice)
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
