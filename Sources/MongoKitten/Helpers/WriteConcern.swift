public struct WriteConcern: Encodable {
    public enum Acknowledgement: Encodable {
        case by(instances: Int)
        case majority
        
        public func encode(to encoder: Encoder) throws {
            var container = try encoder.singleValueContainer()
            
            switch self {
            case .by(let w):
                try container.encode(w)
            case .majority:
                try container.encode("majority")
            }
        }
    }
    
    public var w: Acknowledgement
    public var j: Bool
    public var wtimeout: Int = 0
    
    public init(w: Acknowledgement, j: Bool, wtimeout: Int = 0) {
        self.w = w
        self.j = j
        self.wtimeout = wtimeout
    }
}
