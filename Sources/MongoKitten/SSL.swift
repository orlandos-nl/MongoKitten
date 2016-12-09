import TLS

extension TLS.Socket: MongoTCP {
    public static func open(address hostname: String, port: UInt16, options:[String:Any]? = nil) throws -> MongoTCP {
        let socket = try TLS.Socket(mode: .client, hostname: hostname, port: port, certificates: .openbsd, verifyHost: options?["sslVerify"] as? Bool ?? true, verifyCertificates: options?["sslVerify"] as? Bool ?? true, cipher: .compat, proto: [.secure])
        
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
