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

public class Migrator<M: Model> {
    public typealias Action = (MeowCollection<M>) throws -> EventLoopFuture<Void>
    
    public let database: MeowDatabase
    
    public init(database: MeowDatabase) {
        self.database = database
    }
    
    private var actions = [Action]()
    
    func execute() -> EventLoopFuture<Void> {
        let collection = self.database.collection(for: M.self)
        let promise = self.database.eventLoop.makePromise(of: Void.self)
        
        var actions = self.actions
        func doNextAction() {
            do {
                guard actions.count > 0 else {
                    promise.succeed(())
                    return
                }
                
                let action = actions.removeFirst()
                let actionResult = try action(collection)
                actionResult.cascadeFailure(to: promise)
                actionResult.whenSuccess {
                    doNextAction()
                }
            } catch {
                promise.fail(error)
            }
        }
        
        doNextAction()
        
        return promise.futureResult
    }
    
    public func add(_ action: @escaping Action) {
        actions.append(action)
    }
}

struct MeowMigration: Model {
    typealias Referenced = Self
    
    static let collectionName = "MeowMigrations"
    
    let _id: String
    let date: Date
    let duration: Double
}

extension MeowDatabase {
    /// Runs a migration closure that is not tied to a certain model
    /// The closure will be executed only once, because the migration is registered in the MeowMigrations collection
    public func migrateCustom(
        _ description: String,
        migration: @escaping () throws -> EventLoopFuture<Void>
    ) -> EventLoopFuture<Void> {
        let fullDescription = "Custom - \(description)"
        
        return MeowMigration.count(
            where: "_id" == fullDescription,
            in: self
        ).flatMap { count in
            if count > 0 {
                // Migration not needed
                return self.eventLoop.makeSucceededFuture(())
            }
            
            print("🐈 Running migration \(description)")
            
            do {
                let start = Date()
                return try migration().flatMap {
                    let end = Date()
                    let duration = end.timeIntervalSince(start)
                    let migration = MeowMigration(_id: fullDescription, date: start, duration: duration)
                    
                    return migration.create(in: self).assertCompleted()
                }
            } catch {
                return self.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
    public func migrate<M: Model>(_ description: String, on model: M.Type, migration: @escaping (Migrator<M>) throws -> Void) -> EventLoopFuture<Void> {
        let fullDescription = "\(M.self) - \(description)"
        
        return MeowMigration.count(
            where: "_id" == fullDescription,
            in: self
        ).flatMap { count in
            if count > 0 {
                // Migration not needed
                return self.eventLoop.makeSucceededFuture(())
            }
            
            print("🐈 Running migration \(description) on \(M.self)")
            
            do {
                let start = Date()
                let migrator = Migrator<M>(database: self)
                try migration(migrator)
                
                return migrator.execute().flatMap {
                    let end = Date()
                    let duration = end.timeIntervalSince(start)
                    let migration = MeowMigration(_id: fullDescription, date: start, duration: duration)
                    
                    return migration.create(in: self).assertCompleted()
                }
            } catch {
                return self.eventLoop.makeFailedFuture(error)
            }
        }
    }
    
}
