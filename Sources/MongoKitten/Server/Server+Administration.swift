import BSON
import CryptoKitten

extension Server {
    /// Provides a list of all existing databases along with basic statistics about them
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/listDatabases/#dbcmd.listDatabases
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func getDatabaseInfos() throws -> Document {
        let request: Document = ["listDatabases": 1]
        
        let reply = try self["admin"].execute(command: request, writing: false).await()
        
        return try firstDocument(in: reply)
    }
    
    /// Returns all existing databases on this server. **Requires access to the `admin` database**
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    ///
    /// - returns: All databases
    public func getDatabases() throws -> [Database] {
        let infos = try getDatabaseInfos()
        guard let databaseInfos = Document(infos["databases"]) else {
            throw MongoError.commandError(error: "No database Document found")
        }
        
        var databases = [Database]()
        for case (_, let dbDef) in databaseInfos {
            guard let dbDef = Document(dbDef), let name = String(dbDef["name"]) else {
                logger.error("Fetching databases list was not successful because a database name was missing")
                logger.error(databaseInfos)
                throw MongoError.commandError(error: "No database name found")
            }
            
            databases.append(self[name])
        }
        
        return databases
    }
    
    /// Copies a database either from one mongod instance to the current mongod instance or within the current mongod
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/copydb/#dbcmd.copydb
    ///
    /// - parameter database: The database to copy
    /// - parameter otherDatabase: The other database
    /// - parameter user: The database's credentials
    /// - parameter remoteHost: The optional remote host to copy from
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func copy(database db: String, to otherDatabase: String, as user: (user: String, nonce: String, password: String)? = nil, at remoteHost: String? = nil, slaveOk: Bool? = nil) throws {
        var command: Document = [
            "copydb": Int32(1),
            ]
        
        if let fromHost = remoteHost {
            command["fromhost"] = fromHost
        }
        
        command["fromdb"] = db
        command["todb"] = otherDatabase
        
        if let slaveOk = slaveOk {
            command["slaveOk"] = slaveOk
        }
        
        if let user = user {
            command["username"] = user.user
            command["nonce"] = user.nonce
            
            let passHash = MD5.hash(Bytes("\(user.user):mongo:\(user.password)".utf8)).hexString
            let key = MD5.hash(Bytes("\(user.nonce)\(user.user)\(passHash))".utf8)).hexString
            command["key"] = key
        }
        
        let reply = try self["admin"].execute(command: command).await()
        let response = try firstDocument(in: reply)
        
        guard Int(response["ok"]) == 1 else {
            logger.error("copydb was not successful because of the following error")
            logger.error(response)
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Clones a database from the specified MongoDB Connection URI
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/clone/#dbcmd.clone
    ///
    /// - parameter url: The URL
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func clone(from url: String) throws {
        let command: Document = [
            "clone": url
        ]
        
        let reply = try self["admin"].execute(command: command).await()
        let response = try firstDocument(in: reply)
        
        guard Int(response["ok"]) == 1 else {
            logger.error("clone was not successful because of the following error")
            logger.error(response)
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Shuts down the MongoDB server
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/shutdown/#dbcmd.shutdown
    ///
    /// - parameter force: Force the s
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func shutdown(forced force: Bool? = nil) throws {
        var command: Document = [
            "shutdown": Int32(1)
        ]
        
        if let force = force {
            command["force"] = force
        }
        
        let response = try firstDocument(in: try self["$cmd"].execute(command: command).await())
        
        guard Int(response["ok"]) == 1 else {
            logger.error("shutdown was not successful because of the following error")
            logger.error(response)
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Flushes all pending writes serverside
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/fsync/#dbcmd.fsync
    ///
    /// - parameter async: If true, dont block the server until the operation is finished
    /// - parameter block: Do we block writing in the meanwhile?
    public func fsync(async asynchronously: Bool? = nil, blocking block: Bool? = nil) throws {
        var command: Document = [
            "fsync": Int32(1)
        ]
        
        if let async = asynchronously {
            command["async"] = async
        }
        
        if let block = block {
            command["block"] = block
        }
        
        let reply = try self[self.clientSettings.credentials?.database ?? "admin"].execute(command: command, writing: true).await()
        let response = try firstDocument(in: reply)
        
        guard Int(response["ok"]) == 1 else {
            logger.error("fsync was not successful because of the following error")
            logger.error(response)
            throw MongoError.commandFailure(error: response)
        }
    }
    
    /// Gets the info from the user
    ///
    /// For more information: https://docs.mongodb.com/manual/reference/command/usersInfo/#dbcmd.usersInfo
    ///
    /// - parameter user: The user's username
    /// - parameter database: The database to get the user from... otherwise uses admin
    /// - parameter showCredentials: Do you want to fetch the user's credentials
    /// - parameter showPrivileges: Do you want to fetch the user's privileges
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    ///
    /// - returns: The user's information (plus optionally the credentials and privileges)
    public func getUserInfo(forUserNamed user: String, inDatabase database: Database? = nil, showCredentials: Bool? = nil, showPrivileges: Bool? = nil) throws -> Document {
        var command: Document = [
            "usersInfo": ["user": user, "db": (database?.name ?? "admin")]
        ]
        
        if let showCredentials = showCredentials {
            command["showCredentials"] = showCredentials
        }
        
        if let showPrivileges = showPrivileges {
            command["showPrivileges"] = showPrivileges
        }
        
        let db = database ?? self["admin"]
        
        let document = try firstDocument(in: try db.execute(command: command, writing: false).await())
        
        guard Int(document["ok"]) == 1 else {
            logger.error("usersInfo was not successful because of the following error")
            logger.error(document)
            throw MongoError.commandFailure(error: document)
        }
        
        guard let users = Document(document["users"]) else {
            logger.error("The user Document received from `usersInfo` could was not recognizable")
            logger.error(document)
            throw MongoError.commandError(error: "No users found")
        }
        
        return users
    }
    
    public func ping() throws {
        let commandMessage = Message.Query(requestID: self.nextMessageID(), flags: [], collection: "admin.$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
            "ping": Int32(1)
            ], returnFields: nil)
        
        let connection = try self.reserveConnection(authenticatedFor: nil)
        
        defer { returnConnection(connection) }
        
        try self.sendAsync(message: commandMessage, overConnection: connection)
    }
    
    /// Returns the MongoDB Build Information
    internal func getBuildInfo() throws -> BuildInfo {
        let commandMessage = Message.Query(requestID: self.nextMessageID(), flags: [], collection: "admin.$cmd", numbersToSkip: 0, numbersToReturn: 1, query: [
            "buildInfo": Int32(1)
            ], returnFields: nil)
        
        let connection = try self.reserveConnection(authenticatedFor: nil)
        
        defer { returnConnection(connection) }
        
        let successResponse = try self.sendAsync(message: commandMessage, overConnection: connection).await()
        
        let successDocument = try firstDocument(in: successResponse)
        
        return try BuildInfo(fromDocument: successDocument)
    }
}
