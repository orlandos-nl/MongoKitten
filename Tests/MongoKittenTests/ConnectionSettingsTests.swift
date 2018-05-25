import XCTest
import MongoKitten

class ConnectionSettingsTests : XCTestCase {
    
    struct ConnectionStringTest {
        enum Result {
            case throwsError
            case connectionSettings(ConnectionSettings)
        }
        
        var string: String
        var expectedResult: Result
    }
    
    let connectionStringTests: [ConnectionStringTest] = [
    .init(
        string: "mongodb://henk:bar@foo.be:1234/kaas?ssl&sslVerify=false",
        expectedResult: .connectionSettings(
    .init(authentication: .scramSha1(username: "henk", password: "bar"), hosts: [.init(hostname: "foo.be", port: 1234)], targetDatabase: "kaas", useSSL: true, verifySSLCertificates: false)
        ))
    ]
    
    func testConnectionStrings() {
        for test in connectionStringTests {
            switch test.expectedResult {
            case .throwsError:
                XCTAssertThrowsError(try ConnectionSettings(test.string))
            case .connectionSettings(let expectedSettings):
                do {
                    let generatedSettings = try ConnectionSettings(test.string)
                    XCTAssertEqual(generatedSettings, expectedSettings)
                } catch {
                    XCTFail("\(error) – String: \(test.string)")
                }
            }
        }
    }
    
}
