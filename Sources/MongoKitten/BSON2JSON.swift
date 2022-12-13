import Foundation
import BSON

extension Binary.SubType {
    var identifier: UInt8 {
        switch self {
        case .generic: return 0x00
        case .function: return 0x01
        case .uuid: return 0x04
        case .md5: return 0x05
        case .userDefined(let byte): return byte
        }
    }
}

struct BSON2JSONSerializer {
    let whitespacesPerPadding = 2
    
    func serializeValue(_ value: Primitive, comma: Bool, padding: Int) -> String {
        let comma = comma ? "," : ""
        if let document = value as? Document {
            return serialize(document: document, padding: padding) + comma + "\n"
        } else {
            let inset = paddingString(length: padding)
            let value = primitiveValue(value)
            return inset + value + comma + "\n"
        }
    }
    
    func primitiveValue(_ value: Primitive) -> String {
        // TODO: numberLong etc.. extendedJSON
        switch value {
        case let objectId as ObjectId:
            return "ObjectId(\"\(objectId.hexString)\")"
        case let int as Int:
            return String(int)
        case let int as Int32:
            return String(int)
        case let double as Double:
            return String(double)
        case let string as String:
            return escapedString(string)
        case let bool as Bool:
            return bool ? "true" : "false"
        case is Null:
            return "null"
        case let binary as Binary:
            return "BinData(\(binary.subType.identifier), \"\(binary.data.base64EncodedString())\")"
        case let date as Date:
            if #available(macOS 12.0, iOS 15, *) {
                return "Date(\"\(date.ISO8601Format())\")"
            } else {
                return "Date(\"\(ISO8601DateFormatter().string(from: date))\")"
            }
        default:
            return "unsupportedtype"
        }
    }
    
    func serializeValue(_ value: Primitive, forKey key: String, comma: Bool, padding: Int) -> String {
        let comma = comma ? "," : ""
        if let document = value as? Document {
            return serialize(document: document, key: key, padding: padding) + comma + "\n"
        } else {
            let inset = paddingString(length: padding)
            let key = escapedString(key)
            let value = primitiveValue(value)
            return inset + key + ": " + value + comma + "\n"
        }
    }
    
    func escapedString(_ string: String) -> String {
        // TODO: Actual escaping
        return "\"\(string)\""
    }
    
    func paddingString(length: Int) -> String {
        String(repeating: " ", count: length * whitespacesPerPadding)
    }
    
    func serialize(document: Document, key: String? = nil, padding: Int = 0, padSelf: Bool = true) -> String {
        // TODO: Extended JSON objects
        
        let inset = paddingString(length: padding)
        
        var base = padSelf ? inset : ""
        
        if let key = key {
            base += escapedString(key)
            base += ": "
        }
        
        if document.isArray {
            base += "[\n"
        } else {
            base += "{\n"
        }
        
        if document.isArray {
            let values = document.values
            for i in 0..<values.count {
                base += serializeValue(values[i], comma: i + 1 < values.count, padding: padding + 1)
            }
        } else {
            let keys = document.keys
            let values = document.values
            let count = keys.count
            for i in 0..<count {
                base += serializeValue(values[i], forKey: keys[i], comma: i + 1 < count, padding: padding + 1)
            }
        }
        
        base += inset
        if document.isArray {
            base += "]"
        } else {
            base += "}"
        }
        
        return base
    }
}
