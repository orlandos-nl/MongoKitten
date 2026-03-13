import BSON
import MongoCore

public struct ExplainCommand: Codable, Sendable {
    public let explain: FindCommand
    public let verbosity: ExplainVerbosity
    
    public init(command: FindCommand, verbosity: ExplainVerbosity) {
        self.explain = command
        self.verbosity = verbosity
    }
}

public enum ExplainVerbosity: String, Codable, Sendable {
    case executionStats, queryPlanner, allPlansExecution
}
