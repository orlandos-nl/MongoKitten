//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

@_exported import BSON
@_exported import Async

import Foundation
import Dispatch

/// A ResponseHandler is a closure that receives a MongoReply to process it
/// It's internal because ReplyMessages are an internal struct that is used for direct communication with MongoDB only
internal typealias ResponseHandler = ((Message) -> Void)

/// A server object is the core of MongoKitten as it's used to communicate to the server.
/// You can select a `Database` by subscripting an instance of this Server with a `String`.
public final class Server {
    public let connectionPool: ConnectionPool
    
    /// The next Request we sent starting at 0
    internal var nextRequestID: Int32 = 0
    
    /// `MongoTCP` Socket bound to the MongoDB Server
    private var connections = [DatabaseConnection]()
    
    /// Whether to verify the remote host or not, that is the question
    internal var sslVerify = true
    
    /// The server's details like the wire protocol version
    internal private(set) var serverData: (maxWriteBatchSize: Int32, maxWireVersion: Int32, minWireVersion: Int32, maxMessageSizeBytes: Int32)?
    
    /// The server's BuildInfo
    ///
    /// Do not access from the initialization process!
    public private(set) var buildInfo: BuildInfo?
    
    /// This driver's information
    fileprivate let driverInformation: MongoDriverInformation
    
    public init(connectionPool: ConnectionPool) {
        self.connectionPool = connectionPool
        self.driverInformation = MongoDriverInformation(appName: "MongoKitten 5")
    }
}
