import BSON

public enum WriteConcern: ValueConvertible {
    case custom(w: ValueConvertible, j: Bool?, wTimeout: Int)
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        switch self {
        case .custom(let w, let j, let timeout):
            return [
                "w": w,
                "j": j,
                "wtimeout": timeout
                ] as Document
        }
    }
}

public enum ReadConcern: String, ValueConvertible {
    case local, majority, linearizable
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        return [
            "level": self.rawValue
        ] as Document
    }
}

/// https://docs.mongodb.com/manual/reference/collation/#collation-document-fields
public struct Collation: CustomValueConvertible {
    let locale: String
    let caseLevel: Bool
//    let caseFirst: Bool
    let strength: Strength
    let numericOrdering: Bool
    let alternate: Alternate
    let maxVariable: IgnorableCharacters?
    let backwards: Bool
    let normalization: Bool
    
    public init?(_ value: BSONPrimitive) {
        guard let doc = value.documentValue else {
            return nil
        }
        
        guard let caseLevel = doc["caseLevel"] as Bool? else {
            return nil
        }
        
        self.locale = doc["locale"] as String? ?? "simple"
        self.strength = (doc.extract("strength") as Strength?) ?? .tertiary
        self.caseLevel = caseLevel
        self.numericOrdering = doc["numericOrdering"] as Bool? ?? false
        self.alternate = (doc.extract("alternate") as Alternate?) ?? .nonIgnorable
        self.normalization = (doc["normalization"] as Bool?) ?? false
        self.backwards = (doc["backwards"] as Bool?) ?? false
        self.maxVariable = doc.extract("maxVariable") as IgnorableCharacters?
    }
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        return [
            "locale": locale,
            "caseLevel": caseLevel,
            "strength": strength,
            "numericOrdering": numericOrdering,
            "alternate": alternate,
            "normalization": normalization,
            "backwards": backwards,
            "maxVariable": maxVariable
        ] as Document
    }
    
    public enum IgnorableCharacters: String, CustomValueConvertible {
        case punct = "punct"
        case space = "space"
        
        public init?(_ value: BSONPrimitive) {
            guard let string = value.string else {
                return nil
            }
            
            switch string {
            case "punct":
                self = .punct
            case "space":
                self = .space
            default:
                return nil
            }
        }
        
        public func makeBSONPrimitive() -> BSONPrimitive {
            return self.rawValue
        }
    }
    
    public enum Alternate: String, CustomValueConvertible {
        case nonIgnorable = "non-ignorable"
        case shifted
        
        public init?(_ value: BSONPrimitive) {
            guard let string = value.string else {
                return nil
            }
            
            switch string {
            case "non-ignorable":
                self = .nonIgnorable
            case "shifted":
                self = .shifted
            default:
                return nil
            }
        }
        
        public func makeBSONPrimitive() -> BSONPrimitive {
            return self.rawValue
        }
    }
    
    public enum Strength: Int32, CustomValueConvertible {
        case primary = 1
        case secondary = 2
        case tertiary = 3
        case quaternary = 4
        case identical = 5
        
        public init?(_ value: BSONPrimitive) {
            guard let number = value.int32 else {
                return nil
            }
            
            switch number {
            case 1:
                self = .primary
            case 2:
                self = .secondary
            case 3:
                self = .tertiary
            case 4:
                self = .quaternary
            case 5:
                self = .identical
            default:
                return nil
            }
        }
        
        public func makeBSONPrimitive() -> BSONPrimitive {
            return self.rawValue
        }
    }
}
