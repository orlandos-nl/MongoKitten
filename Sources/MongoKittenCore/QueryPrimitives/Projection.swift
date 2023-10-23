import BSON
import MongoClient

/// A type respresents a MongoDB projection using a fluent syntax.
/// This type is used as a parameter to the `project` method on `MongoCollection`.
/// 
/// # Example:
/// 
/// ```swift
/// let collection: MongoCollection = ...
/// let projection: Projection = [
///   "name": .included, // explicitly include the field "name"
/// ]
public struct Projection: Encodable, ExpressibleByDictionaryLiteral {
    public internal(set) var document: Document
    public var minimalVersion: WireVersion? {
        func valueUnwrapper(_ value: Primitive) -> WireVersion?{
            switch value {
            case let value as Int32:
                return value == 0 ? .mongo3_4 : nil // indicates excluded fields
            case let value as String:
                return value == "$$REMOVE" ? .mongo3_6 : nil // indicates conditionally excluded fields
            case let value as Document:
                return value.values.compactMap(valueUnwrapper).max()
            default:
                return nil
            }
        }
        
        return self.document.values.compactMap(valueUnwrapper).max()
    }

    /// An expression that can be specified to either include or exclude a field (or some custom value)
    public enum ProjectionExpression: ExpressibleByBooleanLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral, PrimitiveEncodable {
        /// Creates a BSON.Primitive of this ProjectionExpression for easy embedding in Documents
        public func encodePrimitive() throws -> Primitive {
            primitive
        }
        
        public var primitive: Primitive {
            switch self {
            case .custom(let convertible): return convertible
            case .included: return 1 as Int32
            case .excluded: return 0 as Int32
            }
        }

        /// A dictionary literal that makes this a custom ProjectionExpression
        public init(stringLiteral value: String) {
            self = .custom(value)
        }

        /// A custom projection value
        case custom(BSON.Primitive)

        /// Includes this field in the projection
        case included

        /// Excludes this field from the projection
        case excluded

        /// Includes when `true`, Excludes when `false`
        public init(booleanLiteral value: Bool) {
            self = value ? .included : .excluded
        }
        
        public static func projection(ofField field: FieldPath) -> ProjectionExpression {
            return .custom(field.projection)
        }

        /// A dictionary literal that makes this a custom ProjectionExpression
        public init(dictionaryLiteral elements: (FieldPath, ProjectionExpression)...) {
            self = .custom(Document(elements: elements.compactMap { (field, value) in
                return (field.string, value.primitive)
            }))
        }
    }

    public init(dictionaryLiteral elements: (FieldPath, ProjectionExpression)...) {
        // Mapping as a workarond for the compiler being unable to infer the compliance to a protocol
        document = Document(elements: elements.compactMap { (field, value) in
            return (field.string, value.primitive)
        })
    }

    public init(document: Document) {
        self.document = document
    }

    public func encode(to encoder: Encoder) throws {
        try document.encode(to: encoder)
    }

    /// Includes the field in the projection
    /// 
    /// # Example:
    /// 
    /// ```swift
    /// // explicitly include the field "name"
    /// var projection: Projection = [
    ///  "name": .included,
    /// ]
    /// 
    /// // also include the "birthDate" field
    /// projection.include("birthDate")
    /// ```
    public mutating func include(_ field: FieldPath) {
        self.document[field.string] = 1 as Int32
    }

    /// Includes the field in the projection
    /// 
    /// # Example:
    /// 
    /// ```swift
    /// // explicitly include the field "name", other fields are implicitly excluded
    /// var projection: Projection = [
    ///  "name": .included,
    /// ]
    /// 
    /// // also include these fields
    /// projection.include(["birthDate", "username", "email"])
    /// ```
    public mutating func include(_ fields: Set<FieldPath>) {
        for field in fields {
            self.document[field.string] = 1 as Int32
        }
    }

    /// Excludes the field from the projection
    /// 
    /// ```swift
    /// // explicitly exclude the field "name", the rest is implcitly still included
    /// var projection: Projection = [
    ///  "name": .excuded,
    /// ]
    /// 
    /// // also exclude the "birthdate" field
    /// projection.exclude("birthdate")
    /// ```
    public mutating func exclude(_ field: FieldPath) {
        self.document[field.string] = 0 as Int32
    }

    /// Excludes the field from the projection
    /// 
    /// ```swift
    /// // explicitly exclude the field "name", the rest is implcitly still included
    /// var projection: Projection = [
    ///  "name": .excuded,
    /// ]
    /// 
    /// // also exclude these fields, non-specified fields are still included
    /// projection.exclude(["birthdate", "username", "email"])
    /// ```
    public mutating func exclude(_ fields: Set<FieldPath>) {
        for field in fields {
            self.document[field.string] = 0 as Int32
        }
    }

    /// Renames a field.
    /// 
    /// ```swift
    /// var projection: Projection = [:]
    /// projection.rename("name", to: "fullName")
    /// ```
    public mutating func rename(_ field: FieldPath, to newName: FieldPath) {
        self.document[newName.string] = field.projection
    }
    
    /// Makes the entire document available at a new location.
    /// 
    /// # Example
    /// 
    /// Given this input:
    /// 
    /// ```json
    /// { "_id": 1, name: "Joannis", "favouritePet: "Dribbel" }
    /// ````
    ///
    /// ```swift
    /// var projection: Projection = [:]
    /// projection.include("_id")
    /// projection.moveRoot(to: "user")
    /// ````
    /// 
    /// The output will be:
    /// 
    /// ```json
    /// { "_id": 1,  "user": { "_id": 1, "name": "Joannis", "favouritePet": "Dribbel" } }
    /// ```
    public mutating func moveRoot(to field: FieldPath) {
        self.document[field.string] = "$$ROOT"
    }
    
    public mutating func addLiteral(_ literal: Primitive, at name: FieldPath) {
        self.document[name.string] = [
            "$literal": literal
        ] as Document
    }

    public mutating func projectFirstElement(forArray field: FieldPath) {
        self.document[field.string + ".$"] = 1 as Int32
    }

    public mutating func projectFirst(_ elements: Int, forArray field: FieldPath) {
        self.document[field.string] = ["$slice": elements] as Document
    }

    public mutating func projectLast(_ elements: Int, forArray field: FieldPath) {
        self.document[field.string] = ["$slice": -elements] as Document
    }

    public mutating func projectElements(inArray field: FieldPath, from offset: Int, count: Int) {
        self.document[field.string] = [
            "$slice": [offset, count] as Document
            ] as Document
    }

    public static func allExcluding(_ fields: Set<String>) -> Projection {
        var document = Document()

        for field in fields {
            document[field] = 0 as Int32
        }

        return Projection(document: document)
    }

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
