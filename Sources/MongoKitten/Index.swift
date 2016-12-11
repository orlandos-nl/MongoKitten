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
    public enum TextIndexVersion: ValueConvertible {
        case one
        case two
        
        public func makeBSONPrimitive() -> BSONPrimitive {
            if self == .one {
                return Int32(1)
            }
            
            return Int32(2)
        }
    }
    
    case sort(field: String, order: SortOrder)
    case sortedCompound(fields: [(field: String, order: SortOrder)])
    case compound(fields: [(field: String, value: ValueConvertible)])
    case expire(afterSeconds: Int)
    case sparse
    case custom(Document)
    case partialFilter(Document)
    case unique
    case buildInBackground
    case weight(Int)
    case text([String])
    
    internal var document: Document {
        switch self {
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
            //            case .text
        }
    }
}
