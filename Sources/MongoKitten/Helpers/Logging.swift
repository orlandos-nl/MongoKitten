import ExtendedJSON

public protocol Logger {
    func verbose(_ message: String)
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func fatal(_ message: String)
}

extension Logger {
    /// Logs a Document as verbose
    public func verbose(_ message: Document) {
        guard !(self is NotLogger) else { return }
        self.verbose(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    /// Logs a Document as debug
    public func debug(_ message: Document) {
        guard !(self is NotLogger) else { return }
        self.debug(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    /// Logs a Document as info
    public func info(_ message: Document) {
        guard !(self is NotLogger) else { return }
        self.info(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    /// Logs a Document as warning
    public func warning(_ message: Document) {
        guard !(self is NotLogger) else { return }
        self.warning(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    /// Logs a Document as error
    public func error(_ message: Document) {
        guard !(self is NotLogger) else { return }
        self.error(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    /// Logs a Document as fatal
    public func fatal(_ message: Document) {
        guard !(self is NotLogger) else { return }
        self.fatal(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
}

/// Doesn't log
public struct NotLogger : Logger {
    public init() {}
    
    /// Doesn't log
    public func verbose(_ message: String) {}
    
    /// Doesn't log
    public func debug(_ message: String) {}
    
    /// Doesn't log
    public func info(_ message: String) {}
    
    /// Doesn't log
    public func warning(_ message: String) {}
    
    /// Doesn't log
    public func error(_ message: String) {}
    
    /// Doesn't log
    public func fatal(_ message: String) {}
}

/// Prints all logs
public struct PrintLogger : Logger {
    public init() {}
    
    /// Prints a verbose log
    public func verbose(_ message: String) {
        print(message)
    }
    
    /// Prints a debug log
    public func debug(_ message: String) {
        print(message)
    }
    
    /// Prints an info log
    public func info(_ message: String) {
        print(message)
    }
    
    /// Prints a warning log
    public func warning(_ message: String) {
        print(message)
    }
    
    /// Prints an error log
    public func error(_ message: String) {
        print(message)
    }
    
    /// Prints a fatal log
    public func fatal(_ message: String) {
        print(message)
    }
}
