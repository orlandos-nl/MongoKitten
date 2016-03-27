//
//  MongoError.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 22-02-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import struct BSON.Document

/// All MongoDB errors
public enum MongoError : ErrorProtocol {
    /// Can't connect to the MongoDB Server
    case MongoDatabaseUnableToConnect
    
    /// Can't connect since we're already connected
    case MongoDatabaseAlreadyConnected
    
    /// Can't disconnect the socket
    case CannotDisconnect
    
    /// The body of this message is an invalid length
    case InvalidBodyLength
    
    /// -
    case InvalidAction
    
    /// We can't do this action because we're not yet connected
    case MongoDatabaseNotYetConnected
    
    /// Can't insert given documents
    case InsertFailure(documents: [Document])
    
    /// Can't query for documents matching given query
    case QueryFailure(query: Document)
    
    /// Can't update documents with the given selector and update
    case UpdateFailure(updates: [(filter: Document, to: Document, upserting: Bool, multiple: Bool)])
    
    /// Can't remove documents matching the given query
    case RemoveFailure(removals: [(filter: Document, limit: Int32)])
    
    /// Can't find a handler for this reply
    case HandlerNotFound
    
    case Timeout
    
    case CommandFailure
    
    /// Thrown when the initialization of a cursor, on request of the server, failed because of missing data.
    case CursorInitializationError(cursorDocument: Document)
    
    case InvalidReply
    
    case InvalidResponse(documents: [Document])
    
    /// If you get one of these, it's probably a bug on our side. Sorry. Please file a ticket :)
    case InternalInconsistency
    
    case UnsupportedOperations
    
    case InvalidChunkSize(chunkSize: Int)
    
    case NegativeBytesRequested(start: Int, end: Int)
}

public enum MongoAuthenticationError : ErrorProtocol {
    case Base64Failure
    case AuthenticationFailure
    case ServerSignatureInvalid
    case IncorrectCredentials
}

internal enum InternalMongoError : ErrorProtocol {
    case IncorrectReply(reply: Message)
}