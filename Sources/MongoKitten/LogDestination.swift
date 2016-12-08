import BSON
import LogKitten

public class MongoLogDestination: Destination {
    let collection: Collection
    
    public init(_ collection: Collection) {
        self.collection = collection
    }
    
    public func log<L: Level>(_ message: LogKitten.Message<L>, fromFramework framework: Framework) {
        do {
            try collection.insert([
                    "_id": ObjectId(),
                    "message": message,
                    "framework": framework.name
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
}

extension Document: SubjectRepresentable {
    public static var name: String {
        return "Document"
    }

    public func makeSubject() -> Subject {
        let type: UInt8 = self.validatesAsArray() ? 0x03 : 0x04
        return .attributedData(type: type, data: self.bytes)
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
        case .attributedData(let type, let data):
            switch type {
            case 0x03:
                return Document(data: data)
            case 0x04:
                return Document(data: data)
            default:
                return [:] as Document
            }
        }
    }
}
