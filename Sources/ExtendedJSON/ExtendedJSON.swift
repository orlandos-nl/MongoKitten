//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//
@_exported import Cheetah
import BSON
import Foundation
import CryptoSwift
@_exported import KittenCore

internal let isoDateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    return fmt
}()

extension Array where Element == Document {
    public func makeExtendedJSON(typeSafe: Bool = false) -> Cheetah.Value {
        return self.makeDocument().makeExtendedJSON(typeSafe: typeSafe)
    }
}

extension JSONObject {
    internal func parseExtendedJSON() -> Primitive {
        if keys.count == 1, let key = keys.first {
            switch (key, self[key]) {
            case ("$oid", let string as String):
                return (try? ObjectId(string)) ?? string
            case ("$date", let string as String):
                return parseISO8601(from: string) ?? string
            case ("$code", let string as String):
                return JavascriptCode(code: string)
            case ("$minKey", let int as Int):
                guard int == 1 else {
                    return Document(self)
                }
                
                return MinKey()
            case ("$maxKey", let int as Int):
                guard int == 1 else {
                    return Document(self)
                }
                
                return MaxKey()
            default:
                return Document(self)
            }
        } else if keys.count == 2, let firstKey = keys.first, let lastKey = keys.last {
            switch (firstKey, lastKey, self[firstKey], self[lastKey]) {
            case ("$regex", "$options", let regex as String, let options as String):
                return RegularExpression(pattern: regex, options: regexOptions(fromString: options))
            case ("$code", "$scope", let code as String, let scope as JSONObject):
                return JavascriptCode(code: code, withScope: Document(scope))
            case ("$binary", "$type", let base64 as String, let subType as String):
                guard subType.characters.count == 2 else {
                    return Document(self)
                }
                
                guard let data = Data(base64Encoded: base64), let subtype = UInt8(subType[subType.index(subType.startIndex, offsetBy: 2)..<subType.endIndex], radix: 16) else {
                    return Document(self)
                }
                
                return Binary(data: data, withSubtype: Binary.Subtype(rawValue: subtype))
            default:
                return Document(self)
            }
        } else {
            return Document(self)
        }
    }
}

fileprivate func regexOptions(fromString s: String) -> NSRegularExpression.Options {
    var options: NSRegularExpression.Options = []
    
    if s.contains("i") {
        options.update(with: .caseInsensitive)
    }
    
    if s.contains("m") {
        options.update(with: .anchorsMatchLines)
    }
    
    if s.contains("x") {
        options.update(with: .allowCommentsAndWhitespace)
    }
    
    if s.contains("s") {
        options.update(with: .dotMatchesLineSeparators)
    }
    
    return options
}

extension NSRegularExpression.Options {
    func makeOptionString() -> String {
        var options = ""
        
        if self.contains(.caseInsensitive) {
            options.append("i")
        }
        
        if self.contains(.anchorsMatchLines) {
            options.append("m")
        }
        
        if self.contains(.allowCommentsAndWhitespace) {
            options.append("x")
        }
        
        if self.contains(.dotMatchesLineSeparators) {
            options.append("s")
        }
        
        return options
    }
}

extension Document {
    public init?(_ value: Cheetah.Value?) {
        switch value {
        case let array as JSONArray:
            self.init(array)
        case let object as JSONObject:
            self.init(object)
        default:
            return nil
        }
    }
    
    public init(_ object: JSONObject) {
        var dictionary = [(String, Primitive?)]()
        
        for (key, value) in object {
            let primitiveValue: Primitive
            
            switch value {
            case let string as String:
                primitiveValue = string
            case let int as Int:
                primitiveValue = int
            case let double as Double:
                primitiveValue = double
            case let bool as Bool:
                primitiveValue = bool
            case let object as JSONObject:
                primitiveValue = object.parseExtendedJSON()
            case let array as JSONArray:
                primitiveValue = Document(array)
            case is KittenCore.Null:
                primitiveValue = Null()
            default:
                assertionFailure("Invalid (custom) JSON element provided")
                continue
            }
            
            dictionary.append((key, primitiveValue))
        }
        
        self.init(dictionaryElements: dictionary)
    }
    
    public init(_ array: JSONArray) {
        var bsonArray = [Primitive]()
        bsonArray.reserveCapacity(array.count)
        
        for value in array {
            switch value {
            case let string as String:
                bsonArray.append(string)
            case let int as Int:
                bsonArray.append(int)
            case let double as Double:
                bsonArray.append(double)
            case let bool as Bool:
                bsonArray.append(bool)
            case let object as JSONObject:
                bsonArray.append(object.parseExtendedJSON())
            case let array as JSONArray:
                bsonArray.append(Document(array))
            case is NSNull:
                bsonArray.append(NSNull())
            default:
                assertionFailure("Invalid (custom) JSON element provided")
                continue
            }
        }
        
        self.init(array: bsonArray)
    }
    
    public init?(extendedJSON string: String) throws {
        self.init(try JSON.parse(from: string))
    }
    
    public init?(extendedJSON bytes: [UInt8]) throws {
        self.init(try JSON.parse(from: bytes))
    }
    
    public func makeExtendedJSON(typeSafe: Bool = false) -> Cheetah.Value {
        func makeJSONValue(_ original: BSON.Primitive) -> Cheetah.Value {
            switch original {
            case let int as Int:
                if typeSafe {
                    return ["$numberLong": "\(int)"] as JSONObject
                } else {
                    return int
                }
            case let int as Int32:
                return Int(int)
            case let double as Double:
                return double
            case let string as String:
                return string
            case let document as Document:
                return document.makeExtendedJSON(typeSafe: typeSafe)
            case let objectId as ObjectId:
                return ["$oid": objectId.hexString] as JSONObject
            case let bool as Bool:
                return bool
            case let date as Date:
                let dateString = isoDateFormatter.string(from: date)
                return ["$date": dateString] as JSONObject
            case let null as NSNull:
                return null
            case let regex as BSON.RegularExpression:
                return ["$regex": regex.pattern, "$options": regex.options.makeOptionString()] as JSONObject
            case let code as JavascriptCode:
                return ["$code": code.code, "$scope": code.scope?.makeExtendedJSON(typeSafe: true) ?? NSNull()] as JSONObject
            case let binary as Binary:
                return ["$binary": binary.data.base64EncodedString(), "$type": [binary.subtype.rawValue].toHexString()] as JSONObject
            case let timestamp as Timestamp:
                return ["$timestamp": ["t": Int(timestamp.timestamp), "i": Int(timestamp.increment)] as JSONObject] as JSONObject
            case is MinKey:
                return ["$minKey": 1] as JSONObject
            case is MaxKey:
                return ["$maxKey": 1] as JSONObject
            default:
                return NSNull() // TODO: Something different?
            }
        }
        
        if self.validatesAsArray() {
            return JSONArray(self.map { makeJSONValue($0.1) })
        } else {
            return JSONObject(sequence: self.map { ($0.0, makeJSONValue($0.1)) })
        }
    }
}
