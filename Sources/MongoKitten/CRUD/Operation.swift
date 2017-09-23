import Schrodinger

public protocol OperationType {
    associatedtype Result
    
    func execute(on database: Database) throws -> Future<Result>
}

public struct Operation<OT: OperationType> {
    public let operation: OT
    public let collection: Collection
    
    init(_ operation: OT, for collection: Collection) {
        self.operation = operation
        self.collection = collection
    }
}
