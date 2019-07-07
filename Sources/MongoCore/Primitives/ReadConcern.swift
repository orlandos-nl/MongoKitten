public struct ReadConcern: Codable {
    public enum Level: String, Codable {
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
