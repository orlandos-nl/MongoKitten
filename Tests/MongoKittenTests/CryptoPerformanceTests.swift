#if ENABLE_MONGOKITTENCRYPTO_PERFORMANCE_TESTS

import XCTest
import _MongoKittenCrypto

final class CryptoPerformanceTests: XCTestCase {
    static var perfPasses: [(String, String)] { [
        ("password", "longsalt"),
        ("password2", "othersalt"),
        ("somewhatlongpasswordstringthatIwanttotest", "1"),
        ("p", "somewhatlongsaltstringthatIwanttotest"),
    ] }
    
    private func perfRun(_ pbkdf2: some TestPBKDF2) {
        for (password, salt) in Self.perfPasses {
            XCTAssertFalse(pbkdf2.hash(.init(password.utf8), salt: .init(salt.utf8), iterations: 10_000, keySize: .digestSize).hexString.isEmpty)
        }
    }
    
    // Note: Each test is run an extra time before starting measurements to "prime" CPU caches etc.
    
    func testPerformancePBKDF2OldMD5() {
        perfRun(OldPBKDF2(digest: OldMD5()));
        self.measure { perfRun(OldPBKDF2(digest: OldMD5())) }
    }
    
    func testPerformancePBKDF2NewMD5() {
        perfRun(PBKDF2(digest: MD5()));
        self.measure { perfRun(PBKDF2(digest: MD5())) }
    }
    
    func testPerformancePBKDF2OldSHA1() {
        perfRun(OldPBKDF2(digest: OldSHA1()));
        self.measure { perfRun(OldPBKDF2(digest: OldSHA1())) }
    }
    
    func testPerformancePBKDF2NewSHA1() {
        perfRun(PBKDF2(digest: SHA1()));
        self.measure { perfRun(PBKDF2(digest: SHA1())) }
    }
    
    func testPerformancePBKDF2OldSHA256() {
        perfRun(OldPBKDF2(digest: OldSHA256()));
        self.measure { perfRun(OldPBKDF2(digest: OldSHA256())) }
    }
    
    func testPerformancePBKDF2NewSHA256() {
        perfRun(PBKDF2(digest: SHA256()));
        self.measure { perfRun(PBKDF2(digest: SHA256())) }
    }
}

// An extremely condensed copy of the original MD5 implementation.
fileprivate let md5s: [UInt32] = [7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21], md5k: [UInt32] = [0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391]; fileprivate struct OldMD5: Hash { static let littleEndian = true, chunkSize = 64, digestSize = 16; var a0: UInt32 = 0x67452301, b0: UInt32 = 0xefcdab89, c0: UInt32 = 0x98badcfe, d0: UInt32 = 0x10325476, a1: UInt32 = 0, b1: UInt32 = 0, c1: UInt32 = 0, d1: UInt32 = 0, F: UInt32 = 0, g: Int = 0, Mg: UInt32 = 0, processedBytes: UInt64 = 0; mutating func reset() { (a0,b0,c0,d0) = (0x67452301,0xefcdab89,0x98badcfe,0x10325476) }; var hashValue: [UInt8] { var buffer = [UInt8](); buffer.reserveCapacity(16); func convert(_ int: UInt32) { let int = int.littleEndian; buffer.append(UInt8(int & 0xff)); buffer.append(UInt8((int >> 8) & 0xff)); buffer.append(UInt8((int >> 16) & 0xff)); buffer.append(UInt8((int >> 24) & 0xff)) }; convert(a0); convert(b0); convert(c0); convert(d0); return buffer }; mutating func update(from pointer: UnsafePointer<UInt8>) { a1 = a0; b1 = b0; c1 = c0; d1 = d0; for i in 0...63 { switch i { case 0...15: F = (b1 & c1) | ((~b1) & d1); g = i; case 16...31: F = (d1 & b1) | ((~d1) & c1); g = (5 &* i &+ 1) % 16; case 32...47: F = b1 ^ c1 ^ d1; g = (3 &* i &+ 5) % 16; default: F = c1 ^ (b1 | (~d1)); g = (7 &* i) % 16 }; Mg = pointer.advanced(by: g << 2).withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }; F = F &+ a1 &+ md5k[i] &+ Mg; a1 = d1; d1 = c1; c1 = b1; b1 = b1 &+ md5_leftRotate(F, count: md5s[i]) }; a0 = a0 &+ a1; b0 = b0 &+ b1; c0 = c0 &+ c1; d0 = d0 &+ d1 } }; fileprivate func md5_leftRotate(_ x: UInt32, count c: UInt32) -> UInt32 { return (x << c) | (x >> (32 - c)) }
// An extremely condensed copy of the original SHA-1 implementation.
fileprivate struct OldSHA1: Hash { static let littleEndian = false, chunkSize = 64, digestSize = 20; var h0: UInt32 = 0x67452301, h1: UInt32 = 0xEFCDAB89, h2: UInt32 = 0x98BADCFE, h3: UInt32 = 0x10325476, h4: UInt32 = 0xC3D2E1F0, a: UInt32 = 0, b: UInt32 = 0, c: UInt32 = 0, d: UInt32 = 0, e: UInt32 = 0, f: UInt32 = 0, k: UInt32 = 0, temp: UInt32 = 0, processedBytes: UInt64 = 0; mutating func reset() { h0 = 0x67452301; h1 = 0xEFCDAB89; h2 = 0x98BADCFE; h3 = 0x10325476; h4 = 0xC3D2E1F0 }; var hashValue: [UInt8] { var buffer = [UInt8](); buffer.reserveCapacity(16); func convert(_ int: UInt32) { let int = int.littleEndian; buffer.append(UInt8(int & 0xff)); buffer.append(UInt8((int >> 8) & 0xff)); buffer.append(UInt8((int >> 16) & 0xff)); buffer.append(UInt8((int >> 24) & 0xff)) }; convert(h0); convert(h1); convert(h2); convert(h3); convert(h4); return buffer }; mutating func update(from pointer: UnsafePointer<UInt8>) { var w = pointer.withMemoryRebound(to: UInt32.self, capacity: 16, { p in return [p[0].bigEndian,p[1].bigEndian,p[2].bigEndian,p[3].bigEndian,p[4].bigEndian,p[5].bigEndian,p[6].bigEndian,p[7].bigEndian,p[8].bigEndian,p[9].bigEndian,p[10].bigEndian,p[11].bigEndian,p[12].bigEndian,p[13].bigEndian,p[14].bigEndian,p[15].bigEndian] }); w.reserveCapacity(80); for i in 16...79 { w.append(sha1_leftRotate(w[i &- 3] ^ w[i &- 8] ^ w[i &- 14] ^ w[i &- 16], count: 1)) }; a = h0; b = h1; c = h2; d = h3; e = h4; for i in 0...79 { switch i { case 0...19: f = (b & c) | ((~b) & d); k = 0x5A827999; case 20...39: f = b ^ c ^ d; k = 0x6ED9EBA1; case 40...59: f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC; default: f = b ^ c ^ d; k = 0xCA62C1D6 }; temp = sha1_leftRotate(a, count: 5) &+ f &+ e &+ w[i] &+ k; e = d; d = c; c = sha1_leftRotate(b, count: 30); b = a; a = temp }; h0 = h0 &+ a; h1 = h1 &+ b; h2 = h2 &+ c; h3 = h3 &+ d; h4 = h4 &+ e } }; fileprivate func sha1_leftRotate(_ x: UInt32, count c: UInt32) -> UInt32 { return (x << c) | (x >> (32 - c)) }
// An extremely condensed copy of the original SHA-256 implementation.
fileprivate let sha256k: [UInt32] = [0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]; fileprivate struct OldSHA256: Hash { static let littleEndian = false, chunkSize = 64, digestSize = 32; var h0: UInt32 = 0x6a09e667, h1: UInt32 = 0xbb67ae85, h2: UInt32 = 0x3c6ef372, h3: UInt32 = 0xa54ff53a, h4: UInt32 = 0x510e527f, h5: UInt32 = 0x9b05688c, h6: UInt32 = 0x1f83d9ab, h7: UInt32 = 0x5be0cd19, a: UInt32 = 0, b: UInt32 = 0, c: UInt32 = 0, d: UInt32 = 0, e: UInt32 = 0, f: UInt32 = 0, g: UInt32 = 0, h: UInt32 = 0, s0: UInt32 = 0, s1: UInt32 = 0, ch: UInt32 = 0, maj: UInt32 = 0, temp: UInt32 = 0, temp1: UInt32 = 0, temp2: UInt32 = 0, processedBytes: UInt64 = 0; mutating func reset() {h0 = 0x6a09e667; h1 = 0xbb67ae85; h2 = 0x3c6ef372; h3 = 0xa54ff53a; h4 = 0x510e527f; h5 = 0x9b05688c; h6 = 0x1f83d9ab; h7 = 0x5be0cd19 }; var hashValue: [UInt8] { var buffer = [UInt8](); buffer.reserveCapacity(32); func convert(_ int: UInt32) { let int = int.littleEndian; buffer.append(UInt8(int & 0xff)); buffer.append(UInt8((int >> 8) & 0xff)); buffer.append(UInt8((int >> 16) & 0xff)); buffer.append(UInt8((int >> 24) & 0xff)) }; convert(h0); convert(h1); convert(h2); convert(h3); convert(h4); convert(h5); convert(h6); convert(h7); return buffer }; mutating func update(from pointer: UnsafePointer<UInt8>) { var w = [UInt32](repeating: 0, count: 64); pointer.withMemoryRebound(to: UInt32.self, capacity: 16) { pointer in for i in 0...15 { w[i] = pointer[i].bigEndian } }; for i in 16...63 { s0 = sha256_rightRotate(w[i &- 15], count: 7) ^ sha256_rightRotate(w[i &- 15], count: 18) ^ (w[i &- 15] >> 3); s1 = sha256_rightRotate(w[i &- 2], count: 17) ^ sha256_rightRotate(w[i &- 2], count: 19) ^ (w[i &- 2] >> 10); w[i] = w[i &- 16] &+ s0 &+ w[i &- 7] &+ s1 }; a = h0; b = h1; c = h2; d = h3; e = h4; f = h5; g = h6; h = h7; for i in 0...63 { s1 = sha256_rightRotate(e, count: 6) ^ sha256_rightRotate(e, count: 11) ^ sha256_rightRotate(e, count: 25); ch = (e & f) ^ ((~e) & g); temp1 = h &+ s1 &+ ch &+ sha256k[i] &+ w[i]; s0 = sha256_rightRotate(a, count: 2) ^ sha256_rightRotate(a, count: 13) ^ sha256_rightRotate(a, count: 22); maj = (a & b) ^ (a & c) ^ (b & c); temp2 = s0 &+ maj; h = g; g = f; f = e; e = d &+ temp1; d = c; c = b; b = a; a = temp1 &+ temp2 }; h0 = h0 &+ a; h1 = h1 &+ b; h2 = h2 &+ c; h3 = h3 &+ d; h4 = h4 &+ e; h5 = h5 &+ f; h6 = h6 &+ g; h7 = h7 &+ h } }; fileprivate func sha256_rightRotate(_ x: UInt32, count c: UInt32) -> UInt32 { return (x >> c) | (x << (32 &- c)) }
// An extremely condensed copy of the original PBKDF2 implementation.
final class OldPBKDF2 { private var hash: Hash; private let chunkSize: Int, digestSize: Int; init(digest: Hash) { self.hash = digest; self.chunkSize = type(of: hash).chunkSize; self.digestSize = type(of: hash).digestSize }; func hash(_ password: [UInt8], salt: [UInt8], iterations: Int32, keySize: PBKDF2KeySize = .digestSize) -> [UInt8] { precondition(iterations > 0, "You must iterate in PBKDF2 at least once"); precondition(password.count > 0, "You cannot hash an empty password"); precondition(salt.count > 0, "You cannot hash with an empty salt"); let keySize = keySize.test_size(for: hash); precondition(keySize <= Int(((pow(2,32) as Double) - 1) * Double(chunkSize))); let saltSize = salt.count; var salt = salt + [0, 0, 0, 0], password = password; if password.count > chunkSize { password = hash.hash(password, count: password.count) }; if password.count < chunkSize { password = password + [UInt8](repeating: 0, count: chunkSize - password.count) }; var outerPadding = [UInt8](repeating: 0x5c, count: chunkSize), innerPadding = [UInt8](repeating: 0x36, count: chunkSize); pbkdf2_xor(&innerPadding, password, count: chunkSize); pbkdf2_xor(&outerPadding, password, count: chunkSize); func authenticate(message: [UInt8]) -> [UInt8] { let innerPaddingHash = hash.hash(bytes: innerPadding + message); return hash.hash(bytes: outerPadding + innerPaddingHash) }; var output = [UInt8](); output.reserveCapacity(keySize); func calculate(block: UInt32) { salt.withUnsafeMutableBytes { salt in salt.baseAddress!.advanced(by: saltSize).assumingMemoryBound(to: UInt32.self).pointee = block.bigEndian }; var ui = authenticate(message: salt), u1 = ui; if iterations > 1 { for _ in 1..<iterations { ui = authenticate(message: ui); pbkdf2_xor(&u1, ui, count: digestSize) } }; output.append(contentsOf: u1) }; for block in 1...UInt32((keySize + digestSize - 1) / digestSize) { calculate(block: block) }; let extra = output.count &- keySize; if extra >= 0 { output.removeLast(extra); return output }; return output } }; fileprivate func pbkdf2_xor(_ lhs: UnsafeMutablePointer<UInt8>, _ rhs: UnsafePointer<UInt8>, count: Int) { for i in 0..<count { lhs[i] = lhs[i] ^ rhs[i] } }; extension PBKDF2KeySize { fileprivate func test_size(for digest: Hash) -> Int { switch self { case .digestSize: return numericCast(type(of: digest).digestSize); case .fixed(let size): return size } } }; fileprivate protocol TestPBKDF2 { func hash(_ password: [UInt8], salt: [UInt8], iterations: Int32, keySize: PBKDF2KeySize) -> [UInt8] }; extension PBKDF2: TestPBKDF2 {}; extension OldPBKDF2: TestPBKDF2 {}

#endif
