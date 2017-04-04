//
//  HelpfulErrors.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 20/03/2017.
//
//

import BSON

/// An error thrown by an `Insert` operation when writing fails
public struct InsertErrors : Error {
    /// The errors
    public let errors: [InsertError]
    
    /// The successfully inserted IDs
    public let successfulIds: [Primitive]
    
    /// A single insert error
    ///
    /// One insert error per 1000 Documents or 48MB max.
    public struct InsertError {
        /// A list of write errors
        public let writeErrors: [WriteError]
        
        /// A single error
        public struct WriteError {
            /// The failed index in the insert operation
            public let index: Int
            
            /// The error code
            public let code: Int
            
            /// The error message
            public let message: String
            
            /// The affected Document
            public let affectedDocument: Document
        }
    }
}

/// An error thrown by an `Update` operation when writing fails
public struct UpdateError : Error {
    /// The errors
    public let writeErrors: [WriteError]
    
    /// A single error
    public struct WriteError {
        /// The failed index in the update operation
        public let index: Int
        
        /// The error code
        public let code: Int
        
        /// The error message
        public let message: String
        
        /// The query that failed
        public let affectedQuery: Query
        
        /// The update document that failed
        public let affectedUpdate: Document
        
        /// Whether this query was upserting
        public let upserting: Bool
        
        /// Whether this query was updating multiple Documents
        public let multiple: Bool
    }
}

/// An error thrown by an `Remove` operation when writing fails
public struct RemoveError : Error {
    /// The list of errors
    public let writeErrors: [WriteError]
    
    /// A single error
    public struct WriteError {
        /// The failed index in the remove operation
        public let index: Int
        
        /// The error code
        public let code: Int
        
        /// The error message
        public let message: String
        
        /// The affected query
        public let affectedQuery: Query
        
        /// The used limit for this query
        public let limit: Int
    }
}
