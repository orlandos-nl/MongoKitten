import MongoCore

public struct MongoClientDetails: Encodable {
    public struct ApplicationDetails: Encodable {
        public var name: String
    }

    public struct DriverDetails: Encodable {
        public let name = "SwiftMongoClient"
        public let version = "1"
    }

    public struct OSDetails: Encodable {
        #if os(Linux)
        public let type = "Linux"
        public let name: String? = nil // TODO: see if we can fill this in
        #elseif os(macOS)
        public let type = "Darwin"
        public let name: String? = "macOS"
        #elseif os(iOS)
        public let type = "Darwin"
        public let name: String? = "iOS"
        #elseif os(Windows)
        public let type = "Windows"
        public let name: String? = nil
        #else
        public let type = "unknown"
        public let name: String? = nil
        #endif

        #if arch(x86_64)
        public let architecture: String? = "x86_64"
        #else
        public let architecture: String? = nil
        #endif

        public let version: String? = nil
    }

    public var application: ApplicationDetails?
    public var driver = DriverDetails()
    public var os = OSDetails()

    #if swift(>=5.2)
    public let platform: String? = "Swift 5.2"
    #elseif swift(>=5.1)
    public let platform: String? = "Swift 5.1"
    #elseif swift(>=5.0)
    public let platform: String? = "Swift 5.0"
    #elseif swift(>=4.2)
    public let platform: String? = "Swift 4.2"
    #elseif swift(>=4.1)
    public let platform: String? = "Swift 4.1"
    #else
    public let platform: String?
    #endif

    public init(application: ApplicationDetails?) {
        self.application = application
    }
}

internal struct IsMaster: Encodable {
    private let isMaster: Int32 = 1
    internal var saslSupportedMechs: String?
    internal var client: MongoClientDetails?
    internal var isHandshake: Bool

    internal init(clientDetails: MongoClientDetails?, userNamespace: String?, isHandshake: Bool = false) {
        self.client = clientDetails
        self.saslSupportedMechs = userNamespace
        self.isHandshake = isHandshake
    }
}
