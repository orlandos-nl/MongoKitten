import BSON
import LogKitten

/*public class MongoLogDestination: Destination {
    let collection: Collection
    
    public init(_ collection: Collection) {
        self.collection = collection
    }
    
    public func log<L: Level>(_ message: LogKitten.Message<L>, fromFramework framework: String) {
        do {
            try collection.insert([
                    "_id": ObjectId(),
                    "message": message,
                    "framework": framework
                ])
        } catch {
            print("Cannot insert log into database because of an error: \(error)")
        }
    }
}

extension LogKitten.Message: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        return [
            "level": self.level.name,
            "subject": self.subject,
            "date": self.date,
            "source": self.source,
            "origin": [
                "function": self.origin.function,
                "filePath": self.origin.filePath,
                "line": self.origin.line,
                "column": self.origin.column
            ] as Document
        ] as Document
    }
}*/

extension Document: SubjectRepresentable {
    public static var logKittenId = [UInt8:UInt8]()
    
    public static var name: String {
        return "Document"
    }

    public func makeSubject(fromFramework framework: String) -> Subject {
        return .attributedData(type: Document.self, data: self.bytes)
    }
    
    static public func convertToString(fromData data: [UInt8]) -> String {
        return Document(data: data).makeExtendedJSON()
    }
}

extension Subject: ValueConvertible {
    public func makeBSONPrimitive() -> BSONPrimitive {
        switch self {
        case .string(let s):
            return s
        case .attributedData(_, let data):
            return Document(data: data)
        }
    }
}
