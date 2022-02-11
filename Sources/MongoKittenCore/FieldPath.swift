public struct FieldPath: ExpressibleByStringLiteral, ExpressibleByArrayLiteral, Sendable, Hashable {
    public var components = [String]()
    
    public var string: String {
        components.joined(separator: ".")
    }
    
    public var projection: String {
        "$\(string)"
    }
    
    public init(stringLiteral value: String) {
        var value = value
        
        if value.first == "$" {
            value.removeFirst()
        }
        
        self.components = value.components(separatedBy: ".")
    }
    
    public init(arrayLiteral elements: String...) {
        self.components = elements
    }
}
