@_exported import BSON

internal struct Unencoded<T>: Encodable {
    var value: T
    
    func encode(to encoder: Encoder) throws {}
}
