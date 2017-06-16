import Foundation
import BSON

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
    func makeJSONBinary() -> [UInt8] {
        var buffer = [UInt8]()
        
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
    public func makeExtendedJSONString(typeSafe: Bool = false) -> String {
        return String(bytes: makeExtendedJSONData(typeSafe: typeSafe), encoding: .utf8) ?? ""
    }
    
    public func makeExtendedJSONData(typeSafe: Bool = false) -> [UInt8] {
        var buffer = [UInt8]()
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
                buffer.append(contentsOf: [binary.subtype.rawValue].toHexString().utf8)
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
                buffer.append(contentsOf: [UInt8]("null".utf8))
            }
        }
        
        if self.validatesAsArray() {
            buffer.append(arrayOpen)
            
            for value in self.arrayValue {
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
