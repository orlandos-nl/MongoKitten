import MongoCore

public struct MongoClientDetails: Encodable, Sendable {
    public struct ApplicationDetails: Encodable, Sendable {
        public var name: String
    }

    public struct DriverDetails: Encodable, Sendable {
        public let name = "MongoKitten"
        public let version = "7"
    }

    public struct OSDetails: Encodable, Sendable {
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

    public let platform: String? = "Swift"

    public init(application: ApplicationDetails?) {
        self.application = application
    }
}

internal struct IsMaster: Encodable {
    private let isMaster: Int32 = 1
    internal var saslSupportedMechs: String?
    internal var client: MongoClientDetails?

    internal init(clientDetails: MongoClientDetails?, userNamespace: String?) {
        self.client = clientDetails
        self.saslSupportedMechs = userNamespace
    }
}
