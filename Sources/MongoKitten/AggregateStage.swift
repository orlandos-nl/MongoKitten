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
}
