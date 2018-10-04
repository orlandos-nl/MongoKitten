@_exported import BSON
@_exported import NIO

internal struct Unencoded<T>: Encodable {
    var value: T
    
    func encode(to encoder: Encoder) throws {}
}
