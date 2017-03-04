//
//  LogKitten.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 04/03/2017.
//
//

import BSON
import LogKitten
import Cheetah

extension Document: SubjectRepresentable {
    /// Records the common LogKitten ID, used by LogKitten (currently) to identify this registered type
    ///
    /// WARNING: LogKitten is alpha software and subject to change. Do not rely on this
    public static var logKittenId = [Byte:Byte]()
    
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
    static public func convertToString(fromData data: Bytes) -> String {
        return String(bytes: Document(data: data).convert(to: JSONData.self)?.serialize() ?? [], encoding: .utf8) ?? "Unknown Document"
    }
}

/// Makes a Subject convertible to a BSONPrimtive
extension Subject: ValueConvertible {
    /// Converts this Subject to a BSON.Primitive for embedding into a log Document
    ///
    /// WARNING: LogKitten is alpha software and subject to change. Do not rely on this
    public func makePrimitive() -> BSON.Primitive {
        switch self {
        case .string(let s):
            return s
        case .attributedData(_, let data):
            return Document(data: data)
        }
    }
}
