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
        // TODO: add more connection strings
        .init(
            string: "mongodb://henk:bar@foo.be:1234/kaas?ssl&sslVerify=false",
            expectedResult: .connectionSettings(
                .init(authentication: .auto(username: "henk", password: "bar"), hosts: [.init(hostname: "foo.be", port: 1234)], targetDatabase: "kaas", useSSL: true, verifySSLCertificates: false)
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
    
    func test_findAndModify() throws {
        
        do {
            let mongoSettings = try ConnectionSettings("mongodb://localhost:27017/helixtest")
            let elg = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let mongodb = try MongoDatabase.lazyConnect(settings: mongoSettings, on: elg)

            let db = mongodb

            // insert dummy data otherwise mongo won't know that transactions aren't supported because it hasn't found a host just yet since no commands were executed.
            let r = try db["queue_collection"].insert(["email": "nova@helixbooking.com","phone": "12345678900"]).wait()

            // Start transaction
            let transactionDatabase = try db.startTransaction(autoCommitChanges: false)
            // Acquire read lock on dummy data for duration of transaction
            let readLockedDocument = try transactionDatabase["queue_collection"].findOneAndUpdate(where: ["email": "nova@helixbooking.com"],
                                                                                                  to: ["$set": ["readLock": ["id": ObjectId()] as Document]],
                                                                                                  returnValue: .modified).execute().wait()

            // Attempt to modify the document (should fail because I have a read lock on the document)
            let nonTransactionQuery = try db["queue_collection"].findOneAndUpdate(where: ["email": "nova@helixbooking.com"],
                                                        to: ["$set": ["phone": "1111111111"]],
                                                        returnValue: .modified)
                                            .execute()
                                            .wait()
            
            print(nonTransactionQuery)
            
            // Update the document that we have a read lock on.
            let original = try transactionDatabase["queue_collection"].findOneAndUpdate(where: ["email": "nova@helixbooking.com"],
                                                                                        to: ["$set": ["phone": "0000000000"]],
                                                                                        returnValue: .original).execute().wait()
            // verify that the document was not mutated outside the transaction
            print("Original document after transaction update.")
            print(original)
            // Commit the transaction
            try transactionDatabase.commit().wait()

            // Fetch the newly modified document to verify it was mutated after the transaction was commited
            let res = try mongodb["queue_collection"].findOne().wait()
            print("Modified document after transaction update.")
            print(res)
        } catch {
            print(error)
        }
    }
    
}
