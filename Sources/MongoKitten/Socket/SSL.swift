import Socks
import SocksCore
import TLS

extension TLS.Socket: MongoTCP {
    public static func open(address hostname: String, port: UInt16, options: ClientSettings) throws -> MongoTCP {
        let address = hostname.lowercased() == "localhost" ? InternetAddress.localhost(port: port) : InternetAddress.init(hostname: hostname, port: port)
        
        let internetSocket = try TCPInternetSocket(address: address)
        let config = try TLS.Config(mode: .client, certificates: options.sslSettings?.certificates ?? .openbsd, verifyHost: !(options.sslSettings?.invalidHostNameAllowed ?? false), verifyCertificates: !(options.sslSettings?.invalidCertificateAllowed ?? false))
        
        let socket = try TLS.Socket(config: config, socket: internetSocket)
        
        try socket.connect(servername: hostname)
        
        return socket
    }
    
    public func send(data binary: [UInt8]) throws {
        try self.send(binary)
    }
    
    public func receive() throws -> [UInt8] {
        return try self.receive(max: Int(UInt16.max))
    }

    public var isConnected: Bool {
        return !socket.closed
    }
}
