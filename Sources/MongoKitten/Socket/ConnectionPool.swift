import Async

public protocol ConnectionPool {
    func retain() -> Future<DatabaseConnection>
}
