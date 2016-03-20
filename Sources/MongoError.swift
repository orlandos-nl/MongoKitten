//
//  MongoError.swift
//  MongoKitten
//
//  Created by Robbert Brandsma on 22-02-16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import struct BSON.Document

/// All MongoDB errors
public enum MongoError : ErrorType {
    /// Can't connect to the MongoDB Server
    case MongoDatabaseUnableToConnect
    
    /// Can't connect since we're already connected
    case MongoDatabaseAlreadyConnected
    
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
    case UpdateFailure(from: Document, to: Document)
    
    /// Can't remove documents matching the given query
    case RemoveFailure(query: Document)
    
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
}

public enum MongoAuthenticationError : ErrorType {
    case Base64Failure
    case AuthenticationFailure
    case ServerSignatureInvalid
}

internal enum InternalMongoError : ErrorType {
    case IncorrectReply(reply: Message)
}