//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

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

/// Makes a Documetn subjectRepresentable meaning that it can be logged by LogKitten
///
/// WARNING: LogKitten is alpha software and subject to change. Do not rely on this
extension Document: SubjectRepresentable {
    /// Records the common LogKitten ID, used by LogKitten (currently) to identify this registered type
    ///
    /// WARNING: LogKitten is alpha software and subject to change. Do not rely on this
    public static var logKittenId = [UInt8:UInt8]()
    
    /// Returns the common name for this Subject
    ///
    /// WARNING: LogKitten is alpha software and subject to change. Do not rely on this
    public static var name: String {
        return "Document"
    }

    /// Makes this Subject a LogKitten type to log
    ///
    /// WARNING: LogKitten is alpha software and subject to change. Do not rely on this
    public func makeSubject(fromFramework framework: String) -> Subject {
        return .attributedData(type: Document.self, data: self.bytes)
    }
    
    /// Converts this type to a String for logging
    ///
    /// WARNING: LogKitten is alpha software and subject to change. Do not rely on this
    static public func convertToString(fromData data: [UInt8]) -> String {
        return Document(data: data).makeExtendedJSON()
    }
}

/// Makes a Subject convertible to a BSONPrimtive
extension Subject: ValueConvertible {
    /// Converts this Subject to a BSONPrimitive for embedding into a log Document
    ///
    /// WARNING: LogKitten is alpha software and subject to change. Do not rely on this
    public func makeBSONPrimitive() -> BSONPrimitive {
        switch self {
        case .string(let s):
            return s
        case .attributedData(_, let data):
            return Document(data: data)
        }
    }
}
