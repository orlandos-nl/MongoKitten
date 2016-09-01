// Base64.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

public struct Base64 {
    /**
     Decodes the base64 encoded string into an array of UInt8 representing
     bytes. Throws an Base64DecodingError.invalidCharacter if the input string
     is not encoded in valid Base64.
     
     - parameters:
     - string: the string to decode
     - returns: an array of bytes.
     */
    public static func decode(_ string: String) throws -> [UInt8] {
        let ascii: [UInt8] = [
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 62, 64, 62, 64, 63,
                                 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 64, 64, 64, 64, 64, 64,
                                 64, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14,
                                 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 64, 64, 64, 64, 63,
                                 64, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
                                 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
                                 ]
        
        var decoded = [UInt8]()
        var unreadBytes = 0
        
        for character in string.utf8 {
            // If we don't get a valid Base64 Character (excluding =):
            if ascii[Int(character)] > 63 {
                
                // If it's '=', which is padding, we are done with the string!
                if character == 61 {
                    break
                }
                    // Otherwise this is not a valid Base64 encoded string
                else {
                    throw Base64DecodingError.invalidCharacter
                }
            }
            
            unreadBytes += 1
        }
        
        func byte(_ index: Int) -> Int {
            return Int(Array(string.utf8)[index])
        }
        
        var index = 0
        
        while unreadBytes > 4 {
            decoded.append(ascii[byte(index + 0)] << 2 | ascii[byte(index + 1)] >> 4)
            decoded.append(ascii[byte(index + 1)] << 4 | ascii[byte(index + 2)] >> 2)
            decoded.append(ascii[byte(index + 2)] << 6 | ascii[byte(index + 3)])
            index += 4
            unreadBytes -= 4
        }
        
        if unreadBytes > 1 {
            decoded.append(ascii[byte(index + 0)] << 2 | ascii[byte(index + 1)] >> 4)
        }
        
        if unreadBytes > 2 {
            decoded.append(ascii[byte(index + 1)] << 4 | ascii[byte(index + 2)] >> 2)
        }
        
        if unreadBytes > 3 {
            decoded.append(ascii[byte(index + 2)] << 6 | ascii[byte(index + 3)])
        }
        
        return decoded
    }
    
    public static func encode(_ data: [UInt8], specialChars: String = "+/", paddingChar: Character? = "=") -> String {
        let base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" + specialChars
        var encoded: String = ""
        
        func appendCharacterFromBase(_ character: Int) {
            encoded.append(base64[base64.index(base64.startIndex, offsetBy: character)])
        }
        
        func byte(_ index: Int) -> Int {
            return Int(data[index])
        }
        
        let decodedBytes = data.map { Int($0) }
        
        var i = 0
        
        while i < decodedBytes.count - 2 {
            appendCharacterFromBase(( byte(i) >> 2) & 0x3F)
            appendCharacterFromBase(((byte(i)       & 0x3) << 4) | ((byte(i + 1) & 0xF0) >> 4))
            appendCharacterFromBase(((byte(i + 1)   & 0xF) << 2) | ((byte(i + 2) & 0xC0) >> 6))
            appendCharacterFromBase(  byte(i + 2)   & 0x3F)
            i += 3
        }
        
        if i < decodedBytes.count {
            appendCharacterFromBase((byte(i) >> 2) & 0x3F)
            
            if i == decodedBytes.count - 1 {
                appendCharacterFromBase(((byte(i) & 0x3) << 4))
                if let paddingChar = paddingChar {
                    encoded.append(paddingChar)
                }
            } else {
                appendCharacterFromBase(((byte(i)     & 0x3) << 4) | ((byte(i + 1) & 0xF0) >> 4))
                appendCharacterFromBase(((byte(i + 1) & 0xF) << 2))
            }
            
            if let paddingChar = paddingChar {
                encoded.append(paddingChar)
            }
        }
        
        return encoded
    }
    
    public static func urlSafeEncode(_ data: [UInt8]) -> String {
        return Base64.encode(data, specialChars: "-_", paddingChar: nil)
    }
}

enum Base64DecodingError: Error {
    case invalidCharacter
}
