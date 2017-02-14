import BSON

internal let maxInt32 = Int(Int32.max)

public protocol DatabaseRequest {
    associatedtype Response: DatabaseResponse
    
    static var writing: Bool { get }
    
    var collection: MongoCollection { get }
    func execute() throws -> Response
}

public protocol DatabaseResponse {
    var collection: MongoCollection { get }
}

protocol ReadDatabaseRequest : DatabaseRequest { }
protocol WriteDatabaseRequest : DatabaseRequest { }

extension ReadDatabaseRequest {
    public static var writing: Bool {
        return false
    }
}

extension WriteDatabaseRequest {
    public static var writing: Bool {
        return true
    }
}

public protocol Hook {
    var findHook: FindHook? { get }
    var insertHook: InsertHook? { get }
    var updateHook: UpdateHook? { get }
    var removeHook: RemoveHook? { get }
}

internal enum DefaultHook {
    static func findHook(_ request: FindRequest) throws -> Cursor<Document> {
        return try request.execute().cursor
    }
    
    static func insertHook(_ request: InsertRequest) throws -> [ValueConvertible] {
        return try request.execute().identifiers
    }
    
    static func updateHook(_ request: UpdateRequest) throws -> Int {
        return try request.execute().updateCount
    }
    
    static func removeHook(_ request: RemoveRequest) throws -> Int {
        return try request.execute().removeCount
    }
}
