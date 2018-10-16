public struct ReadConcern: Codable {
    public enum Level: Codable, ExpressibleByStringLiteral, RawRepresentable {
        case local, majority, linearizable, available
        case other(String)
        
        public var rawValue: String {
            switch self {
            case .local:
                return "local"
            case .majority:
                return "majority"
            case .linearizable:
                return "linearizable"
            case .available:
                return "available"
            case .other(let string):
                return string
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            try rawValue.encode(to: encoder)
        }
        
        public init(rawValue: String) {
            switch rawValue {
            case "local":
                self = .local
            case "majority":
                self = .majority
            case "linearizable":
                self = .linearizable
            case "available":
                self = .available
            default:
                self = .other(rawValue)
            }
        }
        
        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }
        
        public init(from decoder: Decoder) throws {
            let string = try String(from: decoder)
            self.init(rawValue: string)
        }
    }
    
    public var level: Level
    
    public init(level: Level) {
        self.level = level
    }
}
