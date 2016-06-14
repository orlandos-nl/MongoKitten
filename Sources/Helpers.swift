//
//  Helpers.swift
//  Swongo
//
//  Created by Robbert Brandsma on 14-04-16.
//
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
