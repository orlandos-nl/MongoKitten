import NIOSSL
import Foundation

fileprivate extension Bool {
    init?(queryValue: String?) {
        switch queryValue {
        case nil:
            return nil
        case "0", "false", "FALSE":
            self = false
        default:
            self = true
        }
    }
}

/// Describes the settings for a MongoDB connection, most of which can be represented in a connection string
public struct ConnectionSettings: Equatable {
    /// The authentication details to use with the database
    public enum Authentication: Equatable, Sendable {
        /// Unauthenticated
        case unauthenticated

        /// Automatically select the mechanism
        case auto(username: String, password: String)

        /// SCRAM-SHA1 mechanism
        case scramSha1(username: String, password: String)

        /// SCRAM-SHA256 mechanism
        case scramSha256(username: String, password: String)

        /// Deprecated MongoDB Challenge Response mechanism
        case mongoDBCR(username: String, password: String)
    }

    /// Defines a MongoDB host
    public struct Host: Hashable {
        /// The hostname, like "localhost", "example.com" or "127.0.0.1"
        public var hostname: String

        /// The port. The default MongoDB port is 27017
        public var port: Int

        /// Initializes a new `Host` instance
        ///
        /// - parameter hostname: The hostname
        /// - parameter port: The port
        public init(hostname: String, port: Int) {
            self.hostname = hostname
            self.port = port
        }
        
        internal init(srvHost: String) {
            self.hostname = srvHost
            self.port = 27017
        }

        public init<S: StringProtocol>(_ hostString: S, srv: Bool) throws {
            let splitHost = hostString.split(separator: ":", maxSplits: 1)
            let specifiesPort = splitHost.count == 2

            if specifiesPort {
                if srv {
                    throw MongoInvalidUriError(reason: .srvCannotSpecifyPort)
                }

                let specifiedPortString = splitHost[1]
                
                port = Int(specifiedPortString) ?? 27017
            } else {
                port = 27017
            }

            self.hostname = String(splitHost[0])
        }
    }

    /// The authentication details (mechanism + credentials) to use
    public var authentication: Authentication

    /// Specify the database name associated with the user’s credentials. authSource defaults to the database specified in the connection string.
    /// For authentication mechanisms that delegate credential storage to other services, the authSource value should be $external as with the PLAIN (LDAP) and GSSAPI (Kerberos) authentication mechanisms.
    public var authenticationSource: String?

    /// Hosts to connect to
    public var hosts: [Host]

    /// When true, SSL will be used
    public var useSSL: Bool = false

    /// When SSL is enabled, the CA certificate to use
    /// If `nil`, don't use a custom CA
    public var sslCaCertificatePath: String?
    
    public var sslCaCertificate: NIOSSLCertificate?
    
    /// When true, SSL certificates will be validated
    public var verifySSLCertificates: Bool = true

    /// The maximum number of connections allowed
    public var maximumNumberOfConnections: Int = 1

    /// The connection timeout, in seconds. Defaults to 5 minutes.
    public var connectTimeout: TimeInterval = 300

    /// The time in seconds to attempt a send or receive on a socket before the attempt times out. Defaults to 5 minutes.
    public var socketTimeout: TimeInterval = 300

    /// The target path
    public var targetDatabase: String?

    /// The application name is printed to the mongod logs upon establishing the connection. It is also recorded in the slow query logs and profile collections.
    public var applicationName: String?

    /// Indicates that there is one host for which we'll need to do an query
    public let isSRV: Bool
    
    public var dnsServer: String?
    
    public var queryParameters: [String: String]

    /// Initializes a new connection settings instacen.
    ///
    /// - parameter authentication: See `ConnectionSettings.Authentication`
    /// - parameter authenticationSource: See `ConnectionSettings.authenticationSource`
    /// - parameter hosts: Hosts to connect to
    /// - parameter targetDatabase: The target path
    /// - parameter useSSL: When true, SSL will be used
    /// - parameter verifySSLCertificates: When true, SSL certificates will be validated
    /// - parameter maximumNumberOfConnections: The maximum number of connections allowed
    /// - parameter connectTimeout: See `ConnectionSettings.connectTimeout`
    /// - parameter socketTimeout: See `ConnectionSettings.socketTimeout`
    /// - parameter applicationName: The application name is printed to the mongod logs upon establishing the connection. It is also recorded in the slow query logs and profile collections.
    public init(authentication: Authentication, authenticationSource: String? = nil, hosts: [Host], targetDatabase: String? = nil, useSSL: Bool = false, verifySSLCertificates: Bool = true, maximumNumberOfConnections: Int = 1, connectTimeout: TimeInterval = 300, socketTimeout: TimeInterval = 300, applicationName: String? = nil) {
        self.authentication = authentication
        self.authenticationSource = authenticationSource
        self.hosts = hosts
        self.targetDatabase = targetDatabase
        self.useSSL = useSSL
        self.verifySSLCertificates = verifySSLCertificates
        self.maximumNumberOfConnections = maximumNumberOfConnections
        self.connectTimeout = connectTimeout
        self.socketTimeout = socketTimeout
        self.applicationName = applicationName
        self.isSRV = false
        self.queryParameters = [:]
    }
    
    /// Initializes a new connection settings instacen.
    ///
    /// - parameter authentication: See `ConnectionSettings.Authentication`
    /// - parameter authenticationSource: See `ConnectionSettings.authenticationSource`
    /// - parameter hosts: Hosts to connect to
    /// - parameter targetDatabase: The target path
    /// - parameter useSSL: When true, SSL will be used
    /// - parameter verifySSLCertificates: When true, SSL certificates will be validated
    /// - parameter maximumNumberOfConnections: The maximum number of connections allowed
    /// - parameter connectTimeout: See `ConnectionSettings.connectTimeout`
    /// - parameter socketTimeout: See `ConnectionSettings.socketTimeout`
    /// - parameter applicationName: The application name is printed to the mongod logs upon establishing the connection. It is also recorded in the slow query logs and profile collections.
    public init(authentication: Authentication, authenticationSource: String? = nil, srvHostname: String, targetDatabase: String? = nil, maximumNumberOfConnections: Int = 1, connectTimeout: TimeInterval = 300, socketTimeout: TimeInterval = 300, applicationName: String? = nil) {
        self.authentication = authentication
        self.authenticationSource = authenticationSource
        self.hosts = [Host(srvHost: srvHostname)]
        self.targetDatabase = targetDatabase
        self.useSSL = true
        self.verifySSLCertificates = true
        self.maximumNumberOfConnections = maximumNumberOfConnections
        self.connectTimeout = connectTimeout
        self.socketTimeout = socketTimeout
        self.applicationName = applicationName
        self.isSRV = true
        self.queryParameters = [:]
    }

    /// Parses the given `uri` into the ConnectionSettings
    /// `mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]`
    ///
    /// Supported options include:
    ///
    /// - `authMechanism`: Specifies the authentication mechanism to use, see `ConnectionSettings.Authentication`
    /// - `authSource`: The authentication source, see the documenation on `ConnectionSettings.authenticationSource` for details
    /// - `ssl`: SSL will be used when set to true
    /// - `sslVerify`: When set to `0` or `false`, the SSL certificate will not be verified
    /// - `appname`: The application name is printed to the mongod logs upon establishing the connection. It is also recorded in the slow query logs and profile collections.
    ///
    /// For query options, `0`, `false` and `FALSE` are interpreted as false. All other values, including no value at all (when the key is included), are interpreted as true.
    public init(_ uri: String) throws {
        var uri = uri

        let isSRV: Bool

        // First, remove the mongodb:// scheme
        if uri.starts(with: "mongodb://") {
            uri.removeFirst("mongodb://".count)
            isSRV = false
        } else if uri.starts(with: "mongodb+srv://") {
            uri.removeFirst("mongodb+srv://".count)
            isSRV = true
        } else {
            throw MongoInvalidUriError(reason: .missingMongoDBScheme)
        }
        self.isSRV = isSRV

        // Split the string in parts before and after the authentication details
        let parts = uri.split(separator: "@")

        guard parts.count <= 2, parts.count > 0 else {
            throw MongoInvalidUriError(reason: .uriIsMalformed)
        }

        let uriContainsAuthenticationDetails = parts.count == 2

        // The hosts part, for now, is everything after the authentication details
        var hostsPart = uriContainsAuthenticationDetails ? parts[1] : parts[0]
        var queryParts = hostsPart.split(separator: "?")
        hostsPart = queryParts.removeFirst()
        let queryString = queryParts.first

        // Split the path
        let pathParts = hostsPart.split(separator: "/")
        hostsPart = pathParts[0]

        if pathParts.count > 1 {
            self.targetDatabase = String(pathParts[1])
        }

        // Parse all queries
        var queries = [String: String]()
        queries.reserveCapacity(10)
        
        if let queryString = queryString {
            queryString.split(separator: "&").forEach { queryItem in
                // queryItem can be either like `someOption` or like `someOption=abc`
                let queryItemParts = queryItem.split(separator: "=", maxSplits: 1)
                let queryItemName = String(queryItemParts[0])
                let queryItemValue = queryItemParts.count > 1 ? String(queryItemParts[1]) : ""

                queries[queryItemName] = queryItemValue.removingPercentEncoding
            }
        }
        
        self.queryParameters = queries
        
        // Parse the authentication details, if included
        if uriContainsAuthenticationDetails {
            let authenticationString = parts[0]
            let authenticationParts = authenticationString.split(separator: ":")

            guard authenticationParts.count == 2 else {
                throw MongoInvalidUriError(reason: .malformedAuthenticationDetails)
            }

            guard let username = authenticationParts[0].removingPercentEncoding, let password = authenticationParts[1].removingPercentEncoding else {
                throw MongoInvalidUriError(reason: .malformedAuthenticationDetails)
            }

            switch queries["authMechanism"]?.uppercased() {
            case "SCRAM_SHA_1"?, "SCRAM-SHA-1"?:
                self.authentication = .scramSha1(username: username, password: password)
            case "SCRAM_SHA_256"?, "SCRAM-SHA-256"?:
                self.authentication = .scramSha256(username: username, password: password)
            case "MONGODB_CR"?, "MONGODB-CR"?:
                self.authentication = .mongoDBCR(username: username, password: password)
            case nil:
                self.authentication = .auto(username: username, password: password)
            default:
                throw MongoInvalidUriError(reason: .unsupportedAuthenticationMechanism)
            }
        } else {
            self.authentication = .unauthenticated
        }

        /// Parse the hosts, which may or may not contain a port number
        self.hosts = try hostsPart.split(separator: ",").map { try Host($0, srv: isSRV) }

        if hosts.count != 1 && isSRV {
            throw MongoInvalidUriError(reason: .srvNeedsOneHost)
        }

        // Parse various options
        self.authenticationSource = queries["authSource"]

        if let useSSL = Bool(queryValue: queries["ssl"]) {
            self.useSSL = useSSL
        } else if let useSSL = Bool(queryValue: queries["tls"]) {
            self.useSSL = useSSL
        } else if isSRV {
            self.useSSL = true
        }
        
        if useSSL {
            self.sslCaCertificatePath = queries["tlsCAFile"]
            
//            if let insecure = Bool(queryValue: queries["tlsInsecure"]) {
//                self.sslDisableValidation = insecure
//            }
        }

        // TODO: Custom root cert for IBM bluemix

        if let sslVerify = Bool(queryValue: queries["sslVerify"]) {
            self.verifySSLCertificates = sslVerify
        }

        if let maxConnectionsOption = queries["maxConnections"], let maxConnectionsNumber = Int(maxConnectionsOption), maxConnectionsNumber >= 0 {
            self.maximumNumberOfConnections = maxConnectionsNumber
        }

        if let connectTimeoutMSOption = queries["connectTimeoutMS"], let connectTimeoutMSNumber = Int(connectTimeoutMSOption), connectTimeoutMSNumber > 0 {
            self.connectTimeout = TimeInterval(connectTimeoutMSNumber) / 1000
        }

        if let socketTimeoutMSOption = queries["socketTimeoutMS"], let socketTimeoutMSNumber = Int(socketTimeoutMSOption), socketTimeoutMSNumber > 0 {
            self.socketTimeout = TimeInterval(socketTimeoutMSNumber) / 1000
        }

        self.applicationName = queries["appname"]
        self.dnsServer = queries["dnsServer"]

        for key in [
            "appname", 
            "dnsServer", 
            "sslVerify",
            "maxConnections",
            "connectTimeoutMS",
            "socketTimeoutMS",
            "tlsCAFile",
            "authSource",
            "ssl",
            "tls",
            "authMechanism",
            "dnsServer",
         ] {
            self.queryParameters[key] = nil
        }
    }
}
