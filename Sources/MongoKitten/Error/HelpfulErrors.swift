//
//  HelpfulErrors.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 20/03/2017.
//
//

import BSON

public struct InsertErrors : Error {
    public let errors: [InsertError]
    public let successfulIds: [Primitive]
    
    public struct InsertError {
        public let writeErrors: [WriteError]
        
        public struct WriteError {
            public let index: Int
            public let code: Int
            public let message: String
            public let affectedDocument: Document
        }
    }
}
