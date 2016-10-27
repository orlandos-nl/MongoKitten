import BSON

public struct DBRef: ValueConvertible {
    var collection: Collection
    var id: Value
    
    public func makeBsonValue() -> Value {
        return self.bsonValue
    }
    
    public init(referencing reference: Value, inCollection collection: Collection) {
        self.id = reference
        self.collection = collection
    }
    
    public init(referencing reference: ObjectId, inCollection collection: Collection) {
        self.id = ~reference
        self.collection = collection
    }
    
    public init?(_ document: Document, inServer server: Server) {
        guard let database = document["$db"].stringValue, let collection = document["$ref"].stringValue else {
            return nil
        }
        
        let id = document["$id"]
        
        guard id != .nothing else {
            return nil
        }
        
        self.collection = server[database][collection]
        self.id = id
    }
    
    public init?(_ document: Document, inDatabase database: Database) {
        guard let collection = document["$ref"].stringValue else {
            return nil
        }
        
        let id = document["$id"]
        
        guard id != .nothing else {
            return nil
        }
        
        self.collection = database[collection]
        self.id = id
    }
    
    public var documentValue: Document {
        return [
            "$ref": ~self.collection.name,
            "$id": self.id,
            "$db": ~self.collection.database.name
        ]
    }
    
    public var bsonValue: Value {
        return ~self.documentValue
    }
    
    public func resolve() throws -> Document? {
        return try collection.findOne(matching: "_id" == self.id)
    }
}
