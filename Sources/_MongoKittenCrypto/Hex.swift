import Foundation

extension Array where Element == UInt8 {
    /// The 12 bytes represented as 24-character hex-string
    public var hexString: String {
        var data = Data()
        data.reserveCapacity(self.count * 2)
        
        for byte in self {
            data.append(radix16table[Int(byte / 16)])
            data.append(radix16table[Int(byte % 16)])
        }
        
        return String(data: data, encoding: .utf8)!
    }
}

fileprivate let radix16table: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66]
