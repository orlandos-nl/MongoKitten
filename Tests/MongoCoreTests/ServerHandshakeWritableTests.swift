import XCTest
import BSON
import MongoCore

/// Regression tests for routing writes to a replica-set secondary.
///
/// `ismaster` is the authoritative "this node accepts writes" flag. `readOnly` is only
/// set for a standalone mongod started with `--readOnly`; a replica-set secondary
/// reports `readOnly: false` (or omits it) and `ismaster: false`.
///
/// The pool used to check only `readOnly`, so with `slaveOk` enabled a secondary was
/// considered writable and writes failed with `NotWritablePrimary` (code 10107) after
/// a failover.
final class ServerHandshakeWritableTests: XCTestCase {

    private func handshake(ismaster: Bool, readOnly: Bool?) throws -> ServerHandshake {
        var document = Document()
        document["ok"] = Int32(1)
        document["ismaster"] = ismaster
        document["minWireVersion"] = Int32(0)
        document["maxWireVersion"] = Int32(17)
        if let readOnly {
            document["readOnly"] = readOnly
        }

        let encoded = try BSONEncoder().encode(document)
        return try BSONDecoder().decode(ServerHandshake.self, from: encoded)
    }

    func testPrimaryIsWritable() throws {
        XCTAssertTrue(try handshake(ismaster: true, readOnly: nil).isWritable)
    }

    func testSecondaryIsNotWritable() throws {
        // The regression: a secondary reports `ismaster: false` but not `readOnly`.
        XCTAssertFalse(try handshake(ismaster: false, readOnly: nil).isWritable)
        XCTAssertFalse(try handshake(ismaster: false, readOnly: false).isWritable)
    }

    func testReadOnlyStandaloneIsNotWritable() throws {
        // A standalone mongod started with `--readOnly` reports `ismaster: true`.
        XCTAssertFalse(try handshake(ismaster: true, readOnly: true).isWritable)
    }

    func testMongosIsWritable() throws {
        // A mongos reports `ismaster: true` and `msg: "isdbgrid"`.
        XCTAssertTrue(try handshake(ismaster: true, readOnly: false).isWritable)
    }
}
