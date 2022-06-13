import MongoKittenCore

extension FindCommand: CustomDebugStringConvertible {
    public var debugDescription: String {
        var options = [String]()
        
        if let filter = filter, !filter.isEmpty {
            options.append("\"filter\": \(filter.mongoShell)")
        }
        
        if let sort = sort {
            options.append("\"sort\": \(sort.mongoShell)")
        }
        
        if let projection = projection {
            options.append("\"filter\": \(projection.mongoShell)")
        }
        
        if let skip = skip {
            options.append("\"skip\": \(skip)")
        }
        
        if let limit = limit {
            options.append("\"limit\": \(limit)")
        }
        
        let optionString = options.joined(separator: ",\n  ")
        
        return """
        db.runCommand({
          "find": "\(collection)",
          \(optionString)
        })
        """
    }
}

extension AggregateCommand: CustomDebugStringConvertible {
    public var debugDescription: String {
        var options = [String]()
        
        for stage in pipeline {
            options.append(BSON2JSONSerializer().serialize(document: stage, padding: 2, padSelf: false))
        }
        
        let optionString = options.joined(separator: ",\n    ")
        
        return """
        db.runCommand({
          "aggregate": "\(aggregate)",
          "pipeline": [
            \(optionString)
          ]
        })
        """
    }
}

extension AggregateBuilderPipeline: CustomDebugStringConvertible {
    public var debugDescription: String { makeCommand().debugDescription }
}

extension FindQueryBuilder: CustomDebugStringConvertible {
    public var debugDescription: String { command.debugDescription }
}

extension Document {
    var mongoShell: String {
        BSON2JSONSerializer().serialize(document: self, padding: 1, padSelf: false)
    }
}
