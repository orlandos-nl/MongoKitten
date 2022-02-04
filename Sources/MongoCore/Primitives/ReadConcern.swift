public struct ReadConcern: Codable, Sendable {
    public enum Level: String, Codable, Sendable {
        case local, majority, linearizable, available
    }

    public var level: String

    public init(level: Level) {
        self.level = level.rawValue
    }

    public init(level: String) {
        self.level = level
    }
}
