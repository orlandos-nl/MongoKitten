import Async

public protocol Operation {
    associatedtype Result
    
    // TODO: database -> Pool
    func execute(on database: Database) throws -> Future<Result>
}
