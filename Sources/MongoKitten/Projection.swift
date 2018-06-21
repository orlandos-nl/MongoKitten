import BSON

public struct Projection: Encodable {
    var document: Document
    
    public init(document: Document) {
        self.document = document
    }
    
    public func encode(to encoder: Encoder) throws {
        try document.encode(to: encoder)
    }
    
    public mutating func include(_ field: String) {
        self.document[field] = 1 as Int32
    }
    
    public mutating func include(_ fields: Set<String>) {
        for field in fields {
            self.document[field] = 1 as Int32
        }
    }
    
    public mutating func exclude(_ field: String) {
        self.document[field] = 0 as Int32
    }
    
    public mutating func exclude(_ fields: Set<String>) {
        for field in fields {
            self.document[field] = 0 as Int32
        }
    }
    
    public mutating func projectFirstElement(forArray field: String) {
        self.document[field + ".$"] = 1 as Int32
    }
    
    public mutating func projectFirst(_ elements: Int, forArray field: String) {
        self.document[field] = ["$slice": elements] as Document
    }
    
    public mutating func projectLast(_ elements: Int, forArray field: String) {
        self.document[field] = ["$slice": -elements] as Document
    }
    
    public mutating func rename(_ field: String, to newName: String) {
        self.document[newName] = "$\(field)"
    }
    
    public mutating func rename(_ field: String, to newName: String) {
        self.document[newName] = "$\(field)"
    }
    
    public mutating func projectElements(inArray field: String, from offset: Int, count: Int) {
        self.document[field] = [
            "$slice": [offset, count] as Document
        ] as Document
    }
    
    // TODO: Collection rather than Set?
    public static func allExcluding(_ fields: Set<String>) -> Projection {
        var document = Document()
        
        for field in fields {
            document[field] = 0 as Int32
        }
        
        return Projection(document: document)
    }
    
    // TODO: Collection rather than Set?
    public static func subset(_ fields: Set<String>, suppressingId: Bool = false) -> Projection {
        var document = Document()
        
        for field in fields {
            document[field] = 1 as Int32
        }
        
        if suppressingId {
            document["_id"] = 0 as Int32
        }
        
        return Projection(document: document)
    }
}
