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

public func ==(lhs: ValueConvertible?, rhs: Value) -> Bool {
    let lhs = lhs?.makeBsonValue() ?? .nothing
    
    switch (lhs, rhs) {
    case (.double(_), _):
        return lhs.double == rhs.double
    case (.string(_), _):
        return lhs.string == rhs.stringValue
    case (.document(_), _), (.array(_), _):
        return lhs.document == rhs.documentValue && lhs.documentValue?.validatesAsArray() == rhs.documentValue?.validatesAsArray()
    case (.binary(let subtype1, let data1), .binary(let subtype2, let data2)):
        return subtype1.rawValue == subtype2.rawValue && data1 == data2
    case (.objectId(_), .objectId(_)):
        return lhs.bytes == rhs.bytes
    case (.boolean(let val1), .boolean(let val2)):
        return val1 == val2
    case (.dateTime(let val1), .dateTime(let val2)):
        return val1 == val2
    case (.regularExpression(let exp1, let opt1), .regularExpression(let exp2, let opt2)):
        return exp1 == exp2 && opt1 == opt2
    case (.javascriptCode(let code1), .javascriptCode(let code2)):
        return code1 == code2
    case (.javascriptCodeWithScope(let code1, let scope1), .javascriptCodeWithScope(let code2, let scope2)):
        return code1 == code2 && scope1 == scope2
    case (.int32(_), _):
        return lhs.int32 == rhs.int32
    case (.timestamp(let val1), .timestamp(let val2)):
        return val1 == val2
    case (.int64(_), _):
        return lhs.int64 == rhs.int64
    case (.minKey, .minKey), (.maxKey, .maxKey), (.null, .null), (.nothing, .nothing):
        return true
    default:
        return false
    }
}
