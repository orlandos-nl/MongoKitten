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
    func verbose(_ message: Document) {
        self.verbose(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    func debug(_ message: Document) {
        self.debug(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    func info(_ message: Document) {
        self.info(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    func warning(_ message: Document) {
        self.warning(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    func error(_ message: Document) {
        self.error(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
    
    func fatal(_ message: Document) {
        self.fatal(String(bytes: message.makeExtendedJSON().serialize(), encoding: .utf8) ?? "")
    }
}

public struct NotLogger : Logger {
    public func verbose(_ message: String) {}
    public func debug(_ message: String) {}
    public func info(_ message: String) {}
    public func warning(_ message: String) {}
    public func error(_ message: String) {}
    public func fatal(_ message: String) {}
}

public struct PrintLogger : Logger {
    public func verbose(_ message: String) {
        print(message)
    }
    
    public func debug(_ message: String) {
        print(message)
    }
    
    public func info(_ message: String) {
        print(message)
    }
    
    public func warning(_ message: String) {
        print(message)
    }
    
    public func error(_ message: String) {
        print(message)
    }
    
    public func fatal(_ message: String) {
        print(message)
    }
}
