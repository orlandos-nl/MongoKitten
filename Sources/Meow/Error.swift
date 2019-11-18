import MongoKitten

/// Generic errors thrown by the generator
public enum MeowModelError<M: BaseModel>: Swift.Error {
    /// The value for the given key is missing, or invalid
    case missingOrInvalidValue(key: String, expected: Any.Type, got: Any?)
    
    /// The value is invalid
    case invalidValue(key: String, reason: String)
    
    /// A reference to `type` with id `id` cannot be resolved
    case referenceError(id: Any, type: M.Type)
    
    /// An object cannot be deleted, because of `reason`
    case undeletableObject(reason: String)
    
    /// A file cannot be stored because it exceeds the maximum size
    case fileTooLarge(size: Int, maximum: Int)
    
    /// One or more errors occurred while mass-deleting objects. The `errors` array contains the specific object identifier and error pairs.
    case deletingMultiple(errors: [(ObjectId, Swift.Error)])
    
    /// Meow was not able to validate the database, because `reason`
    case cannotValidate(reason: String)
    
    /// The file cannot be found in GridFS
    case brokenFileReference(ObjectId)
}

enum MeowError: Swift.Error {
    /// A reference to `type` with id `id` cannot be resolved
    case referenceError(id: Any, type: Any.Type)
}
