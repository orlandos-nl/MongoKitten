import Foundation
import MongoKitten
import NIO

enum MigrationError: Error {
    case noDefaultValueFound
    case unknownId
}

fileprivate struct EncodingHelper<V: Encodable>: Encodable {
    var boxedValue: V
}

public class Migrator<M: BaseModel> {
    public typealias Action = @Sendable (MeowCollection<M>) async throws -> ()
    
    public let database: MeowDatabase
    
    public init(database: MeowDatabase) {
        self.database = database
    }
    
    private var actions = [Action]()
    
    func execute() async throws {
        let collection = self.database.collection(for: M.self)
        
        for action in actions {
            try await action(collection)
        }
    }
    
    public func add(_ action: @escaping Action) {
        actions.append(action)
    }
}

struct MeowMigration: MutableModel {
    typealias Referenced = Self
    
    static let collectionName = "MeowMigrations"
    
    let _id: String
    let date: Date
    let duration: Double
}

extension MeowDatabase {
    /// Runs a migration closure that is not tied to a certain model
    /// The closure will be executed only once, because the migration is registered in the MeowMigrations collection
    ///
    /// Migrations are uniquely identified by their description.
    ///
    /// - Warning: DO NOT ALTER THE DESCRITIONS
    public func migrateCustom(
        _ description: String,
        migration: @Sendable @escaping () async throws -> ()
    ) async throws {
        let fullDescription = "Custom - \(description)"
        
        let count = try await MeowMigration.count(
            where: "_id" == fullDescription,
            in: self
        )
        
        if count > 0 {
            // Migration not needed
            return
        }
            
        print("🐈 Running migration \(description)")
        
        let start = Date()
        try await migration()
        let end = Date()
        let duration = end.timeIntervalSince(start)
        let migration = MeowMigration(_id: fullDescription, date: start, duration: duration)
        try await migration.save(in: self)
    }
    
    /// Runs a migration closure that _is_ tied to a certain model
    /// The closure will be executed only once, because the migration is registered in the MeowMigrations collection
    ///
    /// Migrations are uniquely identified by their description.
    ///
    /// - Warning: DO NOT ALTER THE DESCRITIONS
    public func migrate<M: BaseModel>(_ description: String, on model: M.Type, migration: @Sendable @escaping (Migrator<M>) async throws -> Void) async throws {
        let fullDescription = "\(M.self) - \(description)"
        if try await Reference<MeowMigration>(unsafeTo: fullDescription).exists(in: self) {
            // Migration not needed
            return
        }
        
        raw.pool.logger.info("🐈 Running migration \(description) on \(M.self)")
        
        let start = Date()
        let migrator = Migrator<M>(database: self)
        try await migration(migrator)
        try await migrator.execute()
        let end = Date()
        let duration = end.timeIntervalSince(start)
        let migration = MeowMigration(_id: fullDescription, date: start, duration: duration)
        
        try await migration.save(in: self).assertCompleted()
    }
}
