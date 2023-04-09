import Vapor
import MongoKitten

private struct MongoDBStorageKey: StorageKey {
    typealias Value = MongoDatabase
}
