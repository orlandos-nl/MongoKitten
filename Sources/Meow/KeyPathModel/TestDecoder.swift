internal struct TestDecoder: Decoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey : Any]
    
    init() {
        self.codingPath = []
        self.userInfo = [:]
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        KeyedDecodingContainer(
            KeyedTestDecodingContainer<Key>(decoder: self)
        )
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        UnkeyedTestDecodingContainer(decoder: self)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw CannotActuallyDecode()
    }
}

struct KeyedTestDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: TestDecoder
    var codingPath: [CodingKey] { decoder.codingPath }
    var allKeys: [Key] { [] }
    
    func contains(_ key: Key) -> Bool {
        true
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        throw CannotActuallyDecode()
    }
    
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        var decoder = self.decoder
        decoder.codingPath.append(key)
        
        return try T(from: decoder)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        var decoder = self.decoder
        decoder.codingPath.append(key)
        return UnkeyedTestDecodingContainer(decoder: decoder)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        var decoder = self.decoder
        decoder.codingPath.append(key)
        
        return KeyedDecodingContainer(
            KeyedTestDecodingContainer<NestedKey>(decoder: decoder)
        )
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        decoder
    }
    
    func superDecoder() throws -> Decoder {
        decoder
    }
}

struct ArrayElementCodingKey: CodingKey {
    var stringValue: String { "$" }
    var intValue: Int? { nil }
    
    init() {}
    init?(intValue: Int) { nil }
    init?(stringValue: String) { nil }
}

struct UnkeyedTestDecodingContainer: UnkeyedDecodingContainer {
    let decoder: TestDecoder
    var codingPath: [CodingKey] { decoder.codingPath }
    var count: Int? { nil }
    var currentIndex: Int { 0 }
    var isAtEnd: Bool { true }
    
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        var decoder = self.decoder
        decoder.codingPath.append(ArrayElementCodingKey())
        
        return try T(from: decoder)
    }
    
    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        var decoder = self.decoder
        decoder.codingPath.append(ArrayElementCodingKey())
        return UnkeyedTestDecodingContainer(decoder: decoder)
    }
    
    func decodeNil() throws -> Bool {
        throw CannotActuallyDecode()
    }
    
    func superDecoder() throws -> Decoder {
        decoder
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        var decoder = self.decoder
        decoder.codingPath.append(ArrayElementCodingKey())
        
        return KeyedDecodingContainer(
            KeyedTestDecodingContainer<NestedKey>(decoder: decoder)
        )
    }
}

struct CannotActuallyDecode: Error {}
