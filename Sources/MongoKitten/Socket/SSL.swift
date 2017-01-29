import Socks
import SocksCore
import TLS

/// Makes TLS.Socket a MongoTCP Socket, powering SSL support
extension TLS.Socket: MongoTCP {
    /// Opens a Socket using TLS to the specified host
    ///
    /// Makes use of the ClientSettings' SSLSettings
    public static func open(address hostname: String, port: UInt16, options: [String:Any]) throws -> MongoTCP {
        let address = hostname.lowercased() == "localhost" ? InternetAddress.localhost(port: port) : InternetAddress.init(hostname: hostname, port: port)
        
        let internetSocket = try TCPInternetSocket(address: address)
        let invalidCertificateAllowed = options["invalidCertificateAllowed"] as? Bool ?? false
        let invalidHostNameAllowed = options["invalidHostNameAllowed"] as? Bool ?? false
        let config = try TLS.Config(mode: .client, certificates: .openbsd, verifyHost: !invalidHostNameAllowed, verifyCertificates: !invalidCertificateAllowed)
        
        let socket = try TLS.Socket(config: config, socket: internetSocket)
        
        try socket.connect(servername: hostname)
        
        return socket
    }
    
    /// Sends the data to the server
    public func send(data binary: [UInt8]) throws {
        try self.send(binary)
    }
    
    /// Receives all available data from the server
    public func receive() throws -> [UInt8] {
        return try self.receive(max: Int(UInt16.max))
    }

    /// Returns `true` then connected, `false` otherwise
    public var isConnected: Bool {
        return !socket.closed
    }
}
