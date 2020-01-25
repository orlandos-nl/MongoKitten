import MongoClient

public struct AggregateBuilderStage {
    internal var stages: [Document]
    
    public init(document: Document) {
        self.stages = [document]
    }
    
    internal init(documents: [Document]) {
        self.stages = documents
    }
    
    public static func match(_ query: Document) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$match": query
        ])
    }
    
    public static func addFields(_ query: Document) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$addFields": query
        ])
    }
    
    public static func sort(_ sort: Sort) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$sort": sort.document
        ])
    }
    
    public static func project(_ projection: Projection) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$project": projection.document
        ])
    }
    
    public static func project(_ fields: String...) -> AggregateBuilderStage {
        var document = Document()
        for field in fields {
            document[field] = Projection.ProjectionExpression.included.makePrimitive()
        }
        
        return AggregateBuilderStage(document: [
            "$project": document
        ])
    }
    
    public static func count(to field: String) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$count": field
        ])
    }
    
    public static func skip(_ n: Int) -> AggregateBuilderStage {
        assert(n > 0)
        
        return AggregateBuilderStage(document: [
            "$skip": n
        ])
    }
    
    public static func limit(_ n: Int) -> AggregateBuilderStage {
        assert(n > 0)
        
        return AggregateBuilderStage(document: [
            "$limit": n
        ])
    }
    
    public static func sample(_ n: Int) -> AggregateBuilderStage {
        assert(n > 0)
        
        return AggregateBuilderStage(document: [
            "$sample": n
        ])
    }
    
    public static func lookup(
        from: String,
        localField: String,
        foreignField: String,
        as newName: String
    ) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: [
            "$lookup": [
                "from": from,
                "localField": localField,
                "foreignField": foreignField,
                "as": newName
            ]
        ])
    }
    
    public static func unwind(
        fieldPath: String,
        includeArrayIndex: String? = nil,
        preserveNullAndEmptyArrays: Bool? = nil
    ) -> AggregateBuilderStage {
        var d = Document()
        d["path"] = fieldPath
        
        if let incl = includeArrayIndex {
            d["includeArrayIndex"] = incl
        }
        
        if let pres = preserveNullAndEmptyArrays {
            d["preserveNullAndEmptyArrays"] = pres
        }
        
        return AggregateBuilderStage(document: ["$unwind": d])
    }
    
    public static func replaceRoot(_ newRoot: Document) -> AggregateBuilderStage {
        return AggregateBuilderStage(document: ["$replaceRoot": ["newRoot": newRoot]])
    }
}
