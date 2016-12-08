import BSON

public struct DBRef: ValueConvertible {
    var collection: Collection
    var id: ValueConvertible
    
    public func makeBSONPrimitive() -> BSONPrimitive {
        return self.documentValue
    }
    
    public init(referencing reference: ValueConvertible, inCollection collection: Collection) {
        self.id = reference
        self.collection = collection
    }
    
    public init?(_ document: Document, inServer server: Server) {
        guard let database = document["$db"] as String?, let collection = document["$ref"] as String? else {
            server.debug("Provided DBRef document is not valid")
            server.debug(document)
            return nil
        }
        
        guard let id = document[raw: "$id"] else {
            return nil
        }
        
        self.collection = server[database][collection]
        self.id = id
    }
    
    public init?(_ document: Document, inDatabase database: Database) {
        guard let collection = document["$ref"] as String? else {
            return nil
        }
        
        guard let id = document[raw: "$id"] else {
            return nil
        }
        
        self.collection = database[collection]
        self.id = id
    }
    
    public var documentValue: Document {
        return [
            "$ref": self.collection.name,
            "$id": self.id,
            "$db": self.collection.database.name
        ]
    }
    
    public func resolve() throws -> Document? {
        return try collection.findOne(matching: "_id" == self.id)
    }
}
