import BSON

public enum IndexParameter {
    public enum SortOrder: ValueConvertible {
        case ascending
        case descending
        
        public func makeBsonValue() -> Value {
            if self == .ascending {
                return .int32(1)
            }
            
            return .int32(-1)
        }
    }
    
    public enum TextIndexVersion: ValueConvertible {
        case one
        case two
        
        public func makeBsonValue() -> Value {
            if self == .one {
                return .int32(1)
            }
            
            return .int32(2)
        }
    }
    
    case sort(field: String, order: SortOrder)
    case sortedCompound(fields: [(field: String, order: SortOrder)])
    case compound(fields: [(field: String, value: Value)])
    case expire(afterSeconds: Int)
    case sparse
    case custom(Document)
    case partialFilter(Document)
    case unique
    case buildInBackground
    case weight(Int)
    
    internal var document: Document {
        switch self {
        case .sort(let field, let order):
            return ["key": [field: order.makeBsonValue()]]
        case .sortedCompound(let fields):
            var index: Document = [:]
            
            for field in fields {
                index[field.field] = field.order.makeBsonValue()
            }
            
            return ["key": ~(index.flattened())]
        case .compound(let fields):
            var index: Document = [:]
            
            for field in fields {
                index[field.field] = ~field.value
            }
            
            return ["key": ~(index.flattened())]
        case .expire(let seconds):
            return ["expireAfterSeconds": ~seconds]
        case .sparse:
            return ["sparse": true]
        case .custom(let doc):
            return doc
        case .partialFilter(let filter):
            return ["partialFilterExpression": ~filter]
        case .unique:
            return ["unique": true]
        case .buildInBackground:
            return ["background": true]
        case .weight(let weight):
            return ["weights": .int32(Int32(weight))]
            //            case .text
        }
    }
}
