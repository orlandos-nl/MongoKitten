//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import BSON

/// The options to apply to the creation of an index.
///
/// - one:
/// - two:
/// - sort:
/// - sortedCompound:
/// - compound:
/// - expire:
/// - sparse: the index only references documents with the specified field
/// - custom:
/// - partialFilter:
/// - unique: the index should be unique
/// - buildInBackground: Create the index in the background
/// - weight: the weighting object for use with a text index
/// - text: 
public enum IndexParameter {
    /// A TextIndexVersion defines to MongoDB what kind of text index should be created.
    /// Generally this is `.two`
    public enum TextIndexVersion: ValueConvertible {
        /// First text index version
        case one
        
        /// Currently the default text index version
        case two
        
        /// Converts this TextIndexVersion to something easily embeddable in a Document
        public func makeBSONPrimitive() -> BSONPrimitive {
            if self == .one {
                return Int32(1)
            }
            
            return Int32(2)
        }
    }
    
    /// Applies Collation rules to String comparison
    case collation(Collation)
    
    /// Sorts the specified field with in the given order
    case sort(field: String, order: SortOrder)
    
    /// Sorts the specified fields in the given order. The first specified key is the first key that will be used for sorting.
    ///
    /// The second key will be used for sorting only when documents match equally with on first key
    case sortedCompound(fields: [(field: String, order: SortOrder)])
    
    ///
    case compound(fields: [(field: String, value: ValueConvertible)])
    
    /// Removes a Document after it's been in the database for the provided amount of seconds
    case expire(afterSeconds: Int)
    
    /// Only indexes a Document when the Document contain the indexed fields, even if it's `Null`
    case sparse
    
    /// A custom index Document for unsupported features.
    ///
    /// Generally not useful. Make a Issue or PR for the implemented feature if you happen to need this
    case custom(Document)
    
    /// Partial indexes only index Documents matching certain requirements. Like a user whose age is at least 25 years old. This is done using a provided raw MongoDB Document containing operators
    case partialFilter(Document)
    
    /// Requires indexed fields to be unique
    case unique
    
    /// Builds this index in the background. Useful for applications that have a lot of data
    case buildInBackground
    
    /// https://docs.mongodb.com/manual/tutorial/control-results-of-text-search/
    ///
    /// Used in combination with text indexes
    ///
    /// TODO: Broken. Should be fixed in a minor update which will break the API for this function.
    case weight(Int)
    
    /// Applies text indexing to the provided keys
    case text([String])
    
    /// A Geospatial index on a field
    case geo2dsphere(field: String)
    
    /// The Document representation for this Index
    internal var document: Document {
        switch self {
        case .collation(let collation):
            return ["collation": collation]
        case .text(let keys):
            var doc: Document = [:]
            
            for key in keys {
                doc[key] = "text"
            }
            
            return ["key": doc]
        case .sort(let field, let order):
            return ["key": [field: order] as Document]
        case .sortedCompound(let fields):
            var index: Document = [:]
            
            for field in fields {
                index[raw: field.field] = field.order
            }
            
            return ["key": (index.flattened())]
        case .compound(let fields):
            var index: Document = [:]
            
            for field in fields {
                index[raw: field.field] = field.value
            }
            
            return ["key": (index.flattened())]
        case .expire(let seconds):
            return ["expireAfterSeconds": seconds]
        case .sparse:
            return ["sparse": true]
        case .custom(let doc):
            return doc
        case .partialFilter(let filter):
            return ["partialFilterExpression": filter]
        case .unique:
            return ["unique": true]
        case .buildInBackground:
            return ["background": true]
        case .weight(let weight):
            return ["weights": Int32(weight)]            
        case .geo2dsphere(let field):
            return ["key":[field:"2dsphere"] as Document]
        }
    }
}
