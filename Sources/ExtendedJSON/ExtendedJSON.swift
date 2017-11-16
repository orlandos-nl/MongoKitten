import Foundation
import BSON
import Crypto

fileprivate let objectOpen: UInt8 = 0x7b
fileprivate let objectClose: UInt8 = 0x7d

fileprivate let arrayOpen: UInt8 = 0x5b
fileprivate let arrayClose: UInt8 = 0x5d

fileprivate let slash: UInt8 = 0x3f
fileprivate let colon: UInt8 = 0x3a
fileprivate let stringQuotationMark: UInt8 = 0x22

fileprivate let tab: UInt8 = 0x09
fileprivate let lineFeed: UInt8 = 0x0a
fileprivate let carriageReturn: UInt8 = 0x0d
fileprivate let escape: UInt8 = 0x5c

fileprivate let comma: UInt8 = 0x2c

extension String {
    /// Serializes a Stirng as escaped JSON String
    func makeJSONBinary() -> Data {
        var buffer = Data()
        
        for char in self.utf8 {
            switch char {
            case numericCast(stringQuotationMark):
                buffer.append(contentsOf: "\\\"".utf8)
            case numericCast(escape):
                buffer.append(contentsOf: "\\\\".utf8)
            case numericCast(tab):
                buffer.append(contentsOf: "\\t".utf8)
            case numericCast(lineFeed):
                buffer.append(contentsOf: "\\n".utf8)
            case numericCast(carriageReturn):
                buffer.append(contentsOf: "\\r".utf8)
            case 0x00...0x1F:
                buffer.append(contentsOf: "\\u".utf8)
                let str = String(char, radix: 16, uppercase: true)
                if str.characters.count == 1 {
                    buffer.append(contentsOf: "000\(str)".utf8)
                } else {
                    buffer.append(contentsOf: "00\(str)".utf8)
                }
            default:
                buffer.append(char)
            }
        }
        
        return buffer
    }
}

extension Document {
    /// Serializes a Document to an ExtendedJSON encoded String.
    ///
    /// By default, simplified ExtendedJSON will be used, where Integers are loosely converted (Int32 <-> Int64) as necessary
    ///
    /// ```swift
    /// let document: Document = [
    ///     "_id": try ObjectId(),
    ///     "modifyDate": Date(),
    ///     "age": 21,
    ///      "pets": Int32(4),
    /// ]
    /// document.makeExtendedJSONString()
    /// // prints "{\"_id\":{\"$oid\":\"abcdefabcdefabcdefabcdef\"},\"modifyDate\":{\"$date\":\"2017-07-02'T'20:12.912+02:00\"},\"age\":21,\"pets\":4}"
    /// ```
    ///
    /// This can be configured more strictly using `typeSafe: true`
    ///
    /// ```swift
    /// let document: Document = [
    ///     "_id": try ObjectId(),
    ///     "modifyDate": Date(),
    ///     "age": 21,
    ///     "pets": Int32(4),
    /// ]
    /// document.makeExtendedJSONString(typeSafe: true)
    /// // prints "{\"_id\":{\"$oid\":\"abcdefabcdefabcdefabcdef\"},\"modifyDate\":{\"$date\":\"2017-07-02'T'20:12.912+02:00\"},\"age\":{\"$numberLong\":21},\"pets\":{\"$numberInt\":4}}"
    /// ```
    ///
    /// - parameters typeSafe: If true integers will be encoded with `{"$numberLong": 123}` for `Int64(123)` and `{"$numberInt": 123}` for `Int32(123)`
    /// - returns: An ExtendedJSON String from this Document
    public func makeExtendedJSONString(typeSafe: Bool = false) -> String {
        return String(bytes: makeExtendedJSONData(typeSafe: typeSafe), encoding: .utf8) ?? ""
    }
    
    /// Serializes a Document to an ExtendedJSON encoded UTF8 String.
    ///
    /// By default, simplified ExtendedJSON will be used, where Integers are loosely converted (Int32 <-> Int64) as necessary
    ///
    /// ```swift
    /// let document: Document = [
    ///     "_id": try ObjectId(),
    ///     "modifyDate": Date(),
    ///     "age": 21,
    ///      "pets": Int32(4),
    /// ]
    /// document.makeExtendedJSONData()
    /// // prints "{\"_id\":{\"$oid\":\"abcdefabcdefabcdefabcdef\"},\"modifyDate\":{\"$date\":\"2017-07-02'T'20:12.912+02:00\"},\"age\":21,\"pets\":4}".utf8
    /// ```
    ///
    /// This can be configured more strictly using `typeSafe: true`
    ///
    /// ```swift
    /// let document: Document = [
    ///     "_id": try ObjectId(),
    ///     "modifyDate": Date(),
    ///     "age": 21,
    ///     "pets": Int32(4),
    /// ]
    /// document.makeExtendedJSONData(typeSafe: true)
    /// // prints "{\"_id\":{\"$oid\":\"abcdefabcdefabcdefabcdef\"},\"modifyDate\":{\"$date\":\"2017-07-02'T'20:12.912+02:00\"},\"age\":{\"$numberLong\":21},\"pets\":{\"$numberInt\":4}}".utf8
    /// ```
    ///
    /// - parameters typeSafe: If true integers will be encoded with `{"$numberLong": 123}` for `Int64(123)` and `{"$numberInt": 123}` for `Int32(123)`
    /// - returns: An UTF8 encoded ExtendedJSON `String` from this Document
    public func makeExtendedJSONData(typeSafe: Bool = false) -> Data {
        var buffer = Data()
        buffer.reserveCapacity(self.byteCount)
        
        func objectWithSingle<S: Sequence>(value: S, forKey key: String) where S.Iterator.Element == UInt8 {
            buffer.append(objectOpen)
            
            buffer.append(stringQuotationMark)
            buffer.append(contentsOf: key.makeJSONBinary())
            buffer.append(stringQuotationMark)
            
            buffer.append(colon)
            
            buffer.append(contentsOf: value)
            
            buffer.append(objectClose)
        }
        
        func append(_ value: Primitive) {
            switch value {
            case let int as Int:
                if typeSafe {
                    objectWithSingle(value: int.description.utf8, forKey: "$numberLong")
                } else {
                    buffer.append(contentsOf: int.description.utf8)
                }
            case let int as Int32:
                if typeSafe {
                    objectWithSingle(value: int.description.utf8, forKey: "$numberInt")
                } else {
                    buffer.append(contentsOf: int.description.utf8)
                }
            case let double as Double:
                buffer.append(contentsOf: double.description.utf8)
            case let string as String:
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: string.makeJSONBinary())
                buffer.append(stringQuotationMark)
            case let document as Document:
                buffer.append(contentsOf: document.makeExtendedJSONData(typeSafe: typeSafe))
            case let objectId as ObjectId:
                let value = [stringQuotationMark] + objectId.hexString.utf8 + [stringQuotationMark]
                objectWithSingle(value: value, forKey: "$oid")
            case let bool as Bool:
                buffer.append(contentsOf: (bool ? "true".utf8 : "false".utf8))
            case let date as Date:
                let dateString = isoDateFormatter.string(from: date)
                
                let value = [stringQuotationMark] + dateString.makeJSONBinary()
                objectWithSingle(value: value + [stringQuotationMark], forKey: "$date")
            case is NSNull:
                buffer.append(contentsOf: "null".utf8)
            case let regex as BSON.RegularExpression:
                buffer.append(objectOpen)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: "$regex".utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(colon)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: regex.pattern.makeJSONBinary())
                buffer.append(stringQuotationMark)
                
                buffer.append(comma)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: "$options".utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(colon)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: regex.options.makeOptionString().makeJSONBinary())
                buffer.append(stringQuotationMark)
                
                buffer.append(objectClose)
            case let code as JavascriptCode:
                buffer.append(objectOpen)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: "$code".utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(colon)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: code.code.makeJSONBinary())
                buffer.append(stringQuotationMark)
                
                if let scope = code.scope {
                    buffer.append(comma)
                    
                    buffer.append(stringQuotationMark)
                    buffer.append(contentsOf: "$scope".utf8)
                    buffer.append(stringQuotationMark)
                    
                    buffer.append(colon)
                    
                    buffer.append(contentsOf: scope.makeExtendedJSONData(typeSafe: typeSafe))
                }
                
                buffer.append(objectClose)
            case let binary as Binary:
                buffer.append(objectOpen)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: "$binary".utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(colon)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: binary.data.base64EncodedString().utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(comma)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: "$type".utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(colon)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: [binary.subtype.rawValue].hexString.utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(objectClose)
            case let timestamp as Timestamp:
                buffer.append(objectOpen)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: "$timestamp".utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(colon)
                
                buffer.append(objectOpen)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: "t".utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(colon)
                
                buffer.append(contentsOf: timestamp.timestamp.description.utf8)
                
                buffer.append(comma)
                
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: "i".utf8)
                buffer.append(stringQuotationMark)
                
                buffer.append(colon)
                
                buffer.append(contentsOf: timestamp.increment.description.utf8)
                
                buffer.append(objectClose)
                buffer.append(objectClose)
            case is MinKey:
                objectWithSingle(value: 1.description.utf8, forKey: "$minKey")
            case is MaxKey:
                objectWithSingle(value: 1.description.utf8, forKey: "$maxKey")
            default:
                buffer.append(contentsOf: Data("null".utf8))
            }
        }
        
        if self.validatesAsArray() {
            buffer.append(arrayOpen)
            
            for value in self.arrayRepresentation {
                append(value)
                buffer.append(comma)
            }
            
            if buffer.last == comma {
                buffer.removeLast()
            }
            
            buffer.append(arrayClose)
        } else {
            buffer.append(objectOpen)
            
            for (key, value) in self {
                buffer.append(stringQuotationMark)
                buffer.append(contentsOf: key.makeJSONBinary())
                buffer.append(stringQuotationMark)
                
                buffer.append(colon)
                
                append(value)
                
                buffer.append(comma)
            }
            
            if buffer.last == comma {
                buffer.removeLast()
            }
        
            buffer.append(objectClose)
        }
        
        return buffer
    }
}

/// Parses an NSRegularExpression.Options into Regex options String from MongoDB
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


/// Parses a Regex options String from MongoDB into NSRegularExpression.Options
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


fileprivate let isoDateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    return fmt
}()

fileprivate let radix16table: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66]
