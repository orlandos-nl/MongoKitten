import BSON

public struct WriteConcern: Codable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case journaled = "j"
        case acknowledgement = "w"
        case writeTimeoutMS = "wtimeout"
    }

    public struct Acknowledgement: Codable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, Sendable {
        let primitive: Primitive?

        public init(stringLiteral value: String) {
            self.primitive = value
        }

        public init(integerLiteral value: Int32) {
            self.primitive = value
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encodeBSONPrimitive(self.primitive)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            do {
                self.primitive = try container.decode(String.self)
            } catch {
                self.primitive = try container.decode(Int32.self)
            }
        }

        public static var majority: Acknowledgement {
            return "majority"
        }
    }

    public var journaled: Bool?
    public var acknowledgement: Acknowledgement?
    public var writeTimeoutMS: Int?

    public init() {}
    
    public static func majority() -> WriteConcern {
        var concern = WriteConcern()
        concern.acknowledgement = .majority
        return concern
    }
}
