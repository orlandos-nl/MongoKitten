import Foundation
import MongoCore

public struct ServerApiVersion {
    internal enum _Version: String {
        case v1 = "1"
    }
    
    internal let _version: _Version
    
    public static let V1 = ServerApiVersion(_version: .v1)
}


public struct ServerApi {
    var version: ServerApiVersion
    var strict: Bool? = false
    var deprecationErrors: Bool? = false
    
    func propagateCommand( _ command: inout Document) {
        command.appendValue(self.version._version.rawValue, forKey: "apiVersion")
        if let strict = self.strict { command.appendValue(strict, forKey: "apiStrict") }
        if let deprecationErrors = self.deprecationErrors { command.appendValue(deprecationErrors, forKey: "apiDeprecationErrors") }
    }
}
