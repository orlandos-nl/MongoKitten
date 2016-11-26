import BSON

public protocol CustomValueConvertible: ValueConvertible {
    init?(_ value: BSONPrimitive)
}

extension Document {
    public func extract<V: CustomValueConvertible>(_ key: SubscriptExpressionType...) -> V? {
        guard let primitive = self[raw: key]?.makeBSONPrimitive() else {
            return nil
        }
        
        return V(primitive)
    }
    
    public func extract<V: CustomValueConvertible>(_ key: [SubscriptExpressionType]) -> V? {
        guard let primitive = self[raw: key]?.makeBSONPrimitive() else {
            return nil
        }
        
        return V(primitive)
    }
    
    public mutating func updateValue<V: CustomValueConvertible>(_ value: V?, forKey key: SubscriptExpressionType...) {
        self[raw: key] = value
    }
    
    public mutating func updateValue<V: CustomValueConvertible>(_ value: V?, forKey key: [SubscriptExpressionType]) {
        self[raw: key] = value
    }
}
