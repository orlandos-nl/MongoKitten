//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
import BSON
import Cheetah
import KittenCore
import Foundation

public typealias MongoDB = MongoKitten.Database

public protocol MongoValue: Primitive {
    func converted<ST : Any>() -> ST?
}

extension Primitive {
    public func makeMongoValue() -> MongoValue? {
        return self as? MongoValue
    }
}

extension ObjectId: MongoValue, IdentifierType {
    public func converted<S : Any>() -> S? {
        if self is S {
            return self as? S
        } else if String.self is S {
            return self.hexString as? S
        }
        
        return nil
    }
}

extension String: MongoValue {
    public func converted<S : Any>() -> S? {
        if self is S {
            return self as? S
        }
        
        if Int.self is S, let num = Int(self) as? S {
            return num
        }
        
        if Int32.self is S, let num = Int32(self) as? S {
            return num
        }
        
        if Int64.self is S, let num = Int64(self) as? S {
            return num
        }
        
        if Double.self is S, let num = Double(self) as? S {
            return num
        }
        
        if ObjectId.self is S, let objectId = try? ObjectId(self) as? S {
            return objectId
        }
        
        return nil
    }
}

extension Int: MongoValue {
    public func converted<S : Any>() -> S? {
        if self is S {
            return self as? S
        }
        
        if Int32.self is S, self < Int(Int32.max), self > Int(Int32.min), let num = Int32(self) as? S {
            return num
        }
        
        if Int64.self is S, Int64(self) < Int64.max, Int64(self) > Int64.min, let num = Int64(self) as? S {
            return num
        }
        
        if String.self is S, let string = self.description as? S {
            return string
        }
        
        if Bool.self is S, let bool = (self > 0) as? S {
            return bool
        }
        
        return nil
    }
}

extension Int32: MongoValue {
    public func converted<S : Any>() -> S? {
        if self is S {
            return self as? S
        }
        
        if Int.self is S, Int(self) < Int(Int.max), Int(self) > Int.min, let num = Int(self) as? S {
            return num
        }
        
        if Int64.self is S, Int64(self) < Int64.max, Int64(self) > Int64.min, let num = Int64(self) as? S {
            return num
        }
        
        if String.self is S, let string = self.description as? S {
            return string
        }
        
        if Bool.self is S, let bool = (self > 0) as? S {
            return bool
        }
        
        return nil
    }
}

extension Double: MongoValue {
    public func converted<S : Any>() -> S? {
        if self is S {
            return self as? S
        }
        
        if Int.self is S, let num = Int(self) as? S {
            return num
        }
        
        if Int32.self is S, let num = Int32(self) as? S {
            return num
        }
        
        if Int64.self is S, let num = Int64(self) as? S {
            return num
        }
        
        if String.self is S, let string = self.description as? S {
            return string
        }
        
        if Bool.self is S, let bool = (self > 0) as? S {
            return bool
        }
        
        return nil
    }
}

extension Data: MongoValue {
    public var typeIdentifier: Byte {
        return 0x05
    }
    
    public func makeBinary() -> Bytes {
        return Binary(data: self, withSubtype: .generic).makeBytes()
    }

    public func converted<S : Any>() -> S? {
        if self is S {
            return self as? S
        }
        
        if Binary.self is S {
            return Binary(data: self, withSubtype: .generic) as? S
        }
        
        return nil
    }
}

extension Document: MongoValue {
    public func converted<S : Any>() -> S? {
        return self as? S
    }
}

extension Bool: MongoValue {
    public func converted<S : Any>() -> S? {
        if self is S {
            return self as? S
        }
        
        if Int.self is S, let num = (self ? Int(1) : Int(0)) as? S {
            return num
        }
        
        if Int32.self is S, let num = (self ? Int32(1) : Int32(0)) as? S {
            return num
        }
        
        if Int64.self is S, let num = (self ? Int64(1) : Int64(0)) as? S {
            return num
        }
        
        if String.self is S {
            let string = (self ? "true" : "false")
            return string as? S
        }
        
        return nil
    }
}

extension Binary: MongoValue {
    public func converted<S : Any>() -> S? {
        if self is S {
            return self as? S
        }
        
        if Data.self is S {
            return self.data as? S
        }
        
        return nil
    }
}

extension RegularExpression: MongoValue {
    public func converted<S : Any>() -> S? {
        return self as? S
    }
}

extension Date: MongoValue {
    public func converted<S : Any>() -> S? {
        if self is S {
            return self as? S
        }
        
        if Int.self is S, let num = Int(self.timeIntervalSince1970) as? S {
            return num
        }
        
        if Int32.self is S, let num = Int32(self.timeIntervalSince1970) as? S {
            return num
        }
        
        if Int64.self is S, let num = Int64(self.timeIntervalSince1970) as? S {
            return num
        }
        
        if Double.self is S, let num = Double(self.timeIntervalSince1970) as? S {
            return num
        }
        
        if String.self is S, let string = self.timeIntervalSince1970.description as? S {
            return string
        }
        
        return nil
    }
}

extension Document: DatabaseEntity {
    public typealias Identifier = ObjectId
    public typealias SupportedValue = MongoValue
    
    public static let defaultIdentifierField: String = "_id"
    
    public func getIdentifier() -> ObjectId? {
        return self["_id"] as? ObjectId
    }
    
    public func getValue(forKey key: String) -> MongoValue? {
        return self[key]?.makeMongoValue()
    }
    
    public mutating func setValue(to newValue: MongoValue?, forKey key: String) {
        self[key] = newValue
    }
    
    public func getKeys() -> [String] {
        return keys
    }
    
    public func getValues() -> [MongoValue] {
        return self.arrayValue.flatMap {
            $0.makeMongoValue()
        }
    }
    
    public func getKeyValuePairs() -> [String : MongoValue] {
        var pairs = [String: MongoValue]()
        
        for (key, value) in self {
            if let value = value.makeMongoValue() {
                pairs[key] = value
            }
        }
        
        return pairs
    }
    
    public init(dictionary: [String: MongoValue]) {
        self.init(dictionaryElements: dictionary.map { pair in
            return (pair.key as StringVariant, pair.value)
        })
    }
}

extension MongoKitten.Collection : Table {
    public func delete(byId identifier: ObjectId) throws {
        try self.remove(matching: "_id" == identifier)
    }
    
    public func find(matching query: Query?, sorted by: KittenCore.Sort?) throws -> AnyIterator<Document> {
        let mongoSort: MongoKitten.Sort?
        
        if let order = by?.order {
            var doc = Document()
            
            for (key, val) in order {
                if case .ascending = val {
                    doc[key] = Int32(1)
                } else {
                    doc[key] = Int32(-1)
                }
            }
            mongoSort = MongoKitten.Sort(doc)
            
        } else {
            mongoSort = nil
        }
        
        return try self.find(matching: query, sortedBy: mongoSort)
    }
    
    public func store(_ entity: Document) throws {
        try self.insert(entity)
    }
    
    public func findOne(matching query: Query?) throws -> Document? {
        return try self.findOne(matching: query, collation: nil)
    }
    
    public func findOne(byId identifier: ObjectId) throws -> Document? {
        return try self.findOne(matching: "_id" == identifier)
    }
    
    public func update(matching query: Query?, to entity: Document) throws {
        try self.update(matching: query ?? [:], to: entity, upserting: false, multiple: true)
    }
    
    public func update(matchingIdentifier identifier: ObjectId, to entity: Document) throws {
        try self.update(matching: "_id" == identifier, to: entity)
    }
    
    public static func generateIdentifier() -> ObjectId {
        return ObjectId()
    }
    
    public typealias Query = MongoKitten.Query
    public typealias Entity = Document
}

extension Database : KittenCore.Database {
    public typealias T = MongoKitten.Collection
    
    public func getTable(named collection: String) -> MongoKitten.Collection {
        return self[collection]
    }
}

extension ConcreteModel where T == Collection {
    public static var collection: Collection {
        return table
    }
}
