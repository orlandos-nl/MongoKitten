import XCTest
import _MongoKittenCrypto

class CryptoTests: XCTestCase {
    func testMD5() throws {
        var md5 = MD5()
        let data: [(String, String)] = [
            ("The quick brown fox jumps over the lazy dog", "9e107d9d372bb6826bd81d3542a419d6")
        ]
        
        for (input, match) in data {
            let result = md5.hash(bytes: Array(input.utf8)).hexString
            XCTAssertEqual(result, match)
        }
    }
    
    func testSHA1() throws {
        var md5 = SHA1()
        let data: [(String, String)] = [
            ("The quick brown fox jumps over the lazy dog", "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12"),
            ("The quick brown fox jumps over the lazy cog", "de9f2c7fd25e1b3afad3e85a0bd17d9b100db4b3"),
        ]
        
        for (input, match) in data {
            let result = md5.hash(bytes: Array(input.utf8)).hexString
            XCTAssertEqual(result, match)
        }
    }
    
    func testHMAC() throws {
        var md5h = HMAC(hasher: MD5())
        var sha1h = HMAC(hasher: SHA1())
        
        func test<H>(_ hasher: inout HMAC<H>, message: String, key: String, expectation: String) {
            let hash = hasher.authenticate(
                Array(message.utf8),
                withKey: Array(key.utf8)
            ).hexString
            
            XCTAssertEqual(hash, expectation)
        }
        
        test(&md5h, message: "", key: "", expectation: "74e6f7298a9c2d168935f58c001bad88")
        test(&sha1h, message: "", key: "", expectation: "fbdb1d1b18aa6c08324b7d64b71fb76370690e1d")
    }
    
    func testPBKDF2() throws {
        let pbkdf2 = PBKDF2(digest: SHA1())
        
        func test(password: String, salt: String, match: String) {
            let hash = pbkdf2.hash(
                Array(password.utf8),
                salt: Array(salt.utf8),
                iterations: 1_000
            ).hexString
            
            XCTAssertEqual(hash, match)
        }
        
        let passes: [(String, String, String)] = [
            ("password", "longsalt", "1712d0a135d5fcd98f00bb25407035c41f01086a"),
            ("password2", "othersalt", "7a0363dd39e51c2cf86218038ad55f6fbbff6291"),
            ("somewhatlongpasswordstringthatIwanttotest", "1", "8cba8dd99a165833c8d7e3530641c0ecddc6e48c"),
            ("p", "somewhatlongsaltstringthatIwanttotest", "31593b82b859877ea36dc474503d073e6d56a33d"),
        ]
        
        passes.forEach(test)
    }
}
