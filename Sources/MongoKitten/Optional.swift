#if TLS
    import TLS
    
    extension TLS.Socket: MongoTCP {
        public static func open(address hostname: String, port: UInt16) throws -> MongoTCP {
            return try TLS.Socket(mode: .client, hostname: hostname, port: port, certificates: .mozilla, verifyHost: true, verifyCertificates: true, cipher: .secure)
        }
        
        public func send(data binary: [UInt8]) throws {
            try self.send(binary)
        }
        
        public func receive() throws -> [UInt8] {
            return try self.receive(max: Int(UInt16.max))
        }
    }
#endif
