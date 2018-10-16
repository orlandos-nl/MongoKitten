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
        var hasher = SHA1()
        let data: [(String, String)] = [
            ("The quick brown fox jumps over the lazy dog", "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12"),
            ("The quick brown fox jumps over the lazy cog", "de9f2c7fd25e1b3afad3e85a0bd17d9b100db4b3"),
            ]
        
        for (input, match) in data {
            let result = hasher.hash(bytes: Array(input.utf8)).hexString
            XCTAssertEqual(result, match)
        }
    }
    
    func testSHA256() throws {
        var hasher = SHA256()
        let data: [(String, String)] = [
            ("The quick brown fox jumps over the lazy dog", "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592"),
            ("The quick brown fox jumps over the lazy cog", "e4c4d8f3bf76b692de791a173e05321150f7a345b46484fe427f6acc7ecc81be"),
            ("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
            ]
        
        for (input, match) in data {
            let result = hasher.hash(bytes: Array(input.utf8)).hexString
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
    
    func testPBKDF2_SHA1() throws {
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
