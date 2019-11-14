import BSON
import Foundation
import MongoCore
import NIO

extension MongoNamespace {
    public static let administrativeCommand = MongoNamespace(to: "$cmd", inDatabase: "admin")
}

extension MongoServerReply {
    public func isOK() throws -> Bool {
        let document = try getDocument()

        switch document["ok"] {
        case let double as Double where double == 1:
            return true
        case let int as Int32 where int == 1:
            return true
        case let int as Int where int == 1:
            return true
        case let bool as Bool where bool:
            return true
        default:
            break
        }

        return false
    }

    public func assertOK() throws {
        guard try isOK() else {
            throw try MongoGenericErrorReply(reply: self, assertOk: false)
        }
    }

    func assertOK(or error: Error) throws {
        guard try isOK() else {
            throw error
        }
    }

    public func getDocument() throws -> Document {
        guard documents.count == 1 else {
            throw OptionalUnwrapFailure()
        }

        return documents[0]
    }
}

internal extension Decodable {
    init(reply: MongoServerReply, assertOk: Bool = true) throws {
        if assertOk {
            try reply.assertOK()
        }
        
        self = try BSONDecoder().decode(Self.self, from: reply.getDocument())
    }
}

extension String {
    /// Decodes a base64 string into another String
    func base64Decoded() throws -> String {
        guard
            let data = Data(base64Encoded: self),
            let string = String(data: data, encoding: .utf8)
        else {
            throw MongoAuthenticationError(reason: .scramFailure)
        }

        return string
    }
}

extension EventLoopFuture where Value == MongoServerReply {
    func decode<D: Decodable>(_ type: D.Type) -> EventLoopFuture<D> {
        return flatMapThrowing { try D.init(reply:$0) }
    }
}
