// Originally based on CryptoSwift by Marcin Krzyżanowski <marcin.krzyzanowski@gmail.com>
// Copyright (C) 2014 Marcin Krzyżanowski <marcin.krzyzanowski@gmail.com>
// This software is provided 'as-is', without any express or implied warranty.
//
// In no event will the authors be held liable for any damages arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
// - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
// - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
// - This notice may not be removed or altered from any source or binary distribution.


#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public final class SecureBytes {
    private let bytes: [UInt8]
    let count: Int
    
    public init(bytes: [UInt8]) {
        self.bytes = bytes
        self.count = bytes.count
        self.bytes.withUnsafeBufferPointer { (pointer) -> Void in
            mlock(pointer.baseAddress, pointer.count)
        }
    }
    
    deinit {
        self.bytes.withUnsafeBufferPointer { (pointer) -> Void in
            munlock(pointer.baseAddress, pointer.count)
        }
    }
    
    public subscript(index: Int) -> UInt8 {
        return self.bytes[index]
    }
}