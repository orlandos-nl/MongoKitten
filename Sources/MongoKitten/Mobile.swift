#if canImport(mongo_embedded)
import mongo_embedded
import NIO

/// Initializes the MongoDB Mobile library
fileprivate final class Library {
    static var _default: Library?
    static func `default`() throws -> Library {
        if let _default = _default {
            return _default
        }
        
        let lib = try Library()
        self._default = lib
        return lib
    }
    
    fileprivate let library: OpaquePointer
    
    init() throws {
        let statusBuffer = mongo_embedded_v1_status_create()
        var parameters = mongo_embedded_v1_init_params()
        
        guard let library = mongo_embedded_v1_lib_init(&parameters, statusBuffer) else {
            throw MobileError.cannotCreateDB
        }
        
        self.library = library
    }
    
    deinit {
        let statusBuffer = mongo_embedded_v1_status_create()
        let status = mongo_embedded_v1_lib_fini(library, statusBuffer)
        assert(mongo_embedded_v1_error(status) == MONGO_EMBEDDED_V1_SUCCESS, "Deinitialization of MongoKittenMobile failed.")
    }
}

enum MobileError: Error {
    case invalidResponse, invalidState, cannotCreateDB
    case errorMessage(String)
}

// TODO: https://github.com/mongodb/stitch-ios-sdk/blob/c9a0808c9af94d4f8bbfb5ad929b166e3df70d98/Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBService/LocalMongoClient.swift#L138

@available(*, renamed: "Mobile")
public typealias MobileDatabase = Mobile

/// Creates an embedded database instance and connects to it allowing queries.
///
/// This needs to be a used as a singleton/global.
public final class Mobile: _ConnectionPool {
    private let library: Library
    private let database: OpaquePointer
    private let client: OpaquePointer
    private let allocator = ByteBufferAllocator()
    private let serializer = MongoSerializer()
    private let deserializer = MongoDeserializer()
    private let status = mongo_embedded_v1_status_create()
    private var writeBuffer: ByteBuffer
    private var invalid = false
    
    /// Creates a new embedded database using the default configuration
    public convenience init(settings: MobileConfiguration) throws {
        #if canImport(NIOTransportServices)
        let group = PlatformEventLoopGroup(loopCount: 1, defaultQoS: .default)
        #else
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        #endif
        
        try self.init(settings: settings, group: group)
    }
    
    /// Creates a new embedded database using the MobileConfiguration.
    public init(settings: MobileConfiguration, group: PlatformEventLoopGroup) throws {
        let dbPath = settings.storage.dbPath
        let fileManager = FileManager()
        if !fileManager.fileExists(atPath: dbPath) {
            try fileManager.createDirectory(atPath: dbPath, withIntermediateDirectories: true)
        }
        
        let json = String(data: try JSONEncoder().encode(settings), encoding: .utf8)!
        self.library = try Library.default()
        
        guard let database = mongo_embedded_v1_instance_create(library.library, json, status) else {
            throw MobileError.cannotCreateDB
        }
        
        guard let client = mongo_embedded_v1_client_create(database, status) else {
            throw MobileError.cannotCreateDB
        }
        
        self.database = database
        self.client = client
        
        // Preallocate the maximum amount of bytes a MongoDB message can be
        self.writeBuffer = allocator.buffer(capacity: 16_000_000)
        
        super.init(eventLoop: group.next(), sessionManager: SessionManager())
    }
    
    /// Sends a query to the mobile database and completed the command synchronously
    private func _send(context: MongoDBCommandContext, requestId: Int32) {
        do {
            if self.invalid {
                throw MobileError.invalidState
            }
            
            writeBuffer.clear()
            try serializer.encode(data: context, into: &writeBuffer)
        
            let data = try writeBuffer.withUnsafeReadableBytes { writeBuffer -> Data in
                var readPointer: UnsafeMutableRawPointer?
                var readCount = 0
                
                // Sends the data to the MongoDB server and immediately fetches the reply into the readPointer and readCount
                mongo_embedded_v1_client_invoke(
                    client,
                    writeBuffer.baseAddress!,
                    writeBuffer.count,
                    &readPointer,
                    &readCount,
                    status
                )
                
                let error = mongo_embedded_v1_status_get_error(status)
                
                guard error == MONGO_EMBEDDED_V1_SUCCESS.rawValue else {
                    throw MobileError.errorMessage(String(cString: mongo_embedded_v1_status_get_explanation(status)))
                }
                
                // Constructs a `Data` blob from the read bytes
                return Data(bytes: readPointer!, count: readCount)
            }
            
            // Write the data into a ByteBuffer and decode it, making a second copy.
            // TODO: This needs to be optimized
            var buffer = allocator.buffer(capacity: data.count)
            buffer.write(bytes: data)
            
            guard
                try deserializer.parse(from: &buffer) == .continue,
                let reply = deserializer.reply
            else {
                throw MobileError.invalidResponse
            }
            
            context.promise.succeed(result: reply)
            return
        } catch let error {
            self.invalid = true
            context.promise.fail(error)
        }
    }
    
    /// The current request ID, used to generate unique identifiers for MongoDB commands
    private var currentRequestId: Int32 = 0
    
    private func nextRequestId() -> Int32 {
        defer { currentRequestId = currentRequestId &+ 1 }
        
        return currentRequestId
    }
    
    override func send<C>(command: C, session: ClientSession? = nil, transaction: TransactionQueryOptions? = nil) -> EventLoopFuture<ServerReply> where C : MongoDBCommand {
        let promise = self.eventLoop.newPromise(of: ServerReply.self)
        let requestId = nextRequestId()
        let context = MongoDBCommandContext(
            command: command,
            requestID: requestId,
            retry: true,
            session: session,
            transaction: transaction,
            promise: promise
        )

        eventLoop.execute {
            _send(context: context, requestId: requestId)
        }
        
        return promise.futureResult
    }
    
    deinit {
        mongo_embedded_v1_status_destroy(status)
    }
}

public struct MobileConfiguration: Codable {
    public struct Storage: Codable {
        public let dbPath: String
    }
    
    public let storage: Storage
    
    public init(atPath dbPath: String) {
        self.storage = Storage(dbPath: dbPath)
    }
    
    public static func `default`() throws -> MobileConfiguration {
        let dataDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return MobileConfiguration(atPath: dataDirectory.path + "/local_mongodb/0/")
    }
}
#endif
