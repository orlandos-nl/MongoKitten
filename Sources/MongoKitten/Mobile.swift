#if canImport(mongo_embedded)
import mongo_embedded
import NIO

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
            fatalError()
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
    case cannotConnect, notServer, notSocket, alreadyClosed, invalidState
    case errorMessage(String)
}

// TODO: https://github.com/mongodb/stitch-ios-sdk/blob/c9a0808c9af94d4f8bbfb5ad929b166e3df70d98/Darwin/Services/StitchLocalMongoDBService/StitchLocalMongoDBService/LocalMongoClient.swift#L138
public final class MobileDatabase: _ConnectionPool {
    private let library: Library
    private let database: OpaquePointer
    private let client: OpaquePointer
    private let allocator = ByteBufferAllocator()
    private let serializer = MongoSerializer()
    private let deserializer = MongoDeserializer()
    private let status = mongo_embedded_v1_status_create()
    private var writeBuffer: ByteBuffer
    private var invalid = false
    
    public init(settings: MobileConfiguration, group: PlatformEventLoopGroup = PlatformEventLoopGroup(loopCount: 1, defaultQoS: .default)) throws {
        let dbPath = settings.storage.dbPath
        let fileManager = FileManager()
        if !fileManager.fileExists(atPath: dbPath) {
            try fileManager.createDirectory(atPath: dbPath, withIntermediateDirectories: true)
        }
        
        let json = String(data: try JSONEncoder().encode(settings), encoding: .utf8)!
        self.library = try Library.default()
        
        guard let database = mongo_embedded_v1_instance_create(library.library, json, status) else {
            fatalError()
        }
        
        guard let client = mongo_embedded_v1_client_create(database, status) else {
            fatalError()
        }
        
        self.database = database
        self.client = client
        self.writeBuffer = allocator.buffer(capacity: 16_000_000)
        
        super.init(eventLoop: group.next(), sessionManager: SessionManager())
    }
    
    private func _send(context: MongoDBCommandContext, requestId: Int32) {
        do {
            if self.invalid {
                throw MobileError.invalidState
            }
            
            try serializer.encode(data: context, into: &writeBuffer)
        
            let data = try writeBuffer.withUnsafeReadableBytes { writeBuffer -> Data in
                var readPointer: UnsafeMutableRawPointer?
                var readCount = 0
                    
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
                
                return Data(bytes: readPointer!, count: readCount)
            }
            
            var buffer = allocator.buffer(capacity: data.count)
            buffer.write(bytes: data)
            guard
                try deserializer.parse(from: &buffer) == .continue,
                let reply = deserializer.reply
            else {
                fatalError("Invalid response")
            }
            
            context.promise.succeed(result: reply)
            return
        } catch let error {
            self.invalid = true
            print(error)
            context.promise.fail(error: error)
        }
    }
    
    /// The current request ID, used to generate unique identifiers for MongoDB commands
    private var currentRequestId: Int32 = 0
    
    private func nextRequestId() -> Int32 {
        defer { currentRequestId = currentRequestId &+ 1}
        
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
        
        _send(context: context, requestId: requestId)
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
}
#endif
