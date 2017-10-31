import Async

public protocol Operation {
    associatedtype Result
    
    // TODO: database -> Pool
    func execute(on database: DatabaseConnection) throws -> Future<Result>
}
