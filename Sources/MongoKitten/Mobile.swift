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
}

final class MobileChannel: Channel, ChannelCore {
    private let library: Library
    private let database: OpaquePointer
    private let client: OpaquePointer
    private let close: EventLoopPromise<Void>
    private var _pipeline: ChannelPipeline!
    
    let allocator = ByteBufferAllocator()
    let eventLoop: EventLoop
    let localAddress: SocketAddress? = nil
    let remoteAddress: SocketAddress? = nil
    
    private(set) var isOpen = true
    let parent: Channel? = nil
    private(set) var isActive = false
    let isWritable = true
    
    var _unsafe: ChannelCore { return self }
    var pipeline: ChannelPipeline { return _pipeline }
    var closeFuture: EventLoopFuture<Void> { return close.futureResult }
    
    init(settings: MobileConfiguration, group: PlatformEventLoopGroup) throws {
        let json = String(data: try JSONEncoder().encode(settings), encoding: .utf8)!
        
        self.library = try Library.default()
        
        guard let database = mongo_embedded_v1_instance_create(library.library, json, nil) else {
            fatalError()
        }
        
        guard let client = mongo_embedded_v1_client_create(database, nil) else {
            fatalError()
        }
        
        self.eventLoop = group.next()
        self.close = eventLoop.newPromise()
        self.database = database
        self.client = client
        self._pipeline = ChannelPipeline(channel: self)
    }
    
    func setOption<T>(option: T, value: T.OptionType) -> EventLoopFuture<Void> where T : ChannelOption {
        fatalError("No options supported")
    }
    
    func getOption<T>(option: T) -> EventLoopFuture<T.OptionType> where T : ChannelOption {
        fatalError("No options supported")
    }
    
    func localAddress0() throws -> SocketAddress {
        eventLoop.assertInEventLoop()
        
        throw MobileError.notSocket
    }
    
    func remoteAddress0() throws -> SocketAddress {
        eventLoop.assertInEventLoop()
        
        throw MobileError.notSocket
    }
    
    func register0(promise: EventLoopPromise<Void>?) {
        eventLoop.assertInEventLoop()
        
        if isOpen {
            promise?.fail(error: MobileError.alreadyClosed)
            return
        }
        
        promise?.succeed(result: ())
    }
    
    func bind0(to: SocketAddress, promise: EventLoopPromise<Void>?) {
        // This is exclusively a client
        promise?.fail(error: MobileError.notServer)
    }
    
    func connect0(to: SocketAddress, promise: EventLoopPromise<Void>?) {
        // We're connected by default
        promise?.fail(error: MobileError.cannotConnect)
    }
    
    func write0(_ data: NIOAny, promise: EventLoopPromise<Void>?) {
//        eventLoop.assertInEventLoop()
//
//        let buffer = unwrapData(data, as: ByteBuffer.self)
//
//        buffer.withUnsafeReadableBytes { buffer in
//            mongo_embedded_v1_client_invoke(client, buffer.baseAddress!, buffer.count, <#T##output: UnsafeMutablePointer<UnsafeMutableRawPointer?>!##UnsafeMutablePointer<UnsafeMutableRawPointer?>!#>, <#T##output_size: UnsafeMutablePointer<Int>!##UnsafeMutablePointer<Int>!#>, <#T##status: OpaquePointer!##OpaquePointer!#>)
//        }
    }
    
    func flush0() {
        // Nothing to do, flush is handled by the mongo_embedded instance
    }
    
    func read0() {
        eventLoop.assertInEventLoop()
    }
    
    func close0(error: Error, mode: CloseMode, promise: EventLoopPromise<Void>?) {
        self.eventLoop.assertInEventLoop()
        
        if self.isOpen {
            promise?.fail(error: MobileError.alreadyClosed)
            return
        }
        
        self.close.succeed(result: ())
        promise?.succeed(result: ())
    }
    
    func triggerUserOutboundEvent0(_ event: Any, promise: EventLoopPromise<Void>?) {
        promise?.succeed(result: ())
    }
    
    func channelRead0(_ data: NIOAny) {
        // The data is "lost", but that's fine if MongoKitten doesn't need this data
    }
    
    func errorCaught0(error: Error) {
        // Don't do anything, handling errors before this is not a requirement
    }
    
}

public final class MobileDatabase: _ConnectionPool {
    private let library: Library
    private let database: OpaquePointer
    private let client: OpaquePointer
    private let allocator = ByteBufferAllocator()
    private let serializer = MongoSerializer()
    private let deserializer = MongoDeserializer()
    private var writeBuffer: ByteBuffer
    private var readBuffer: ByteBuffer
    private let status = mongo_embedded_v1_status_create()
    private var invalid = false
    
    public init(settings: MobileConfiguration, group: PlatformEventLoopGroup = PlatformEventLoopGroup(loopCount: 1, defaultQoS: .default)) throws {
        let json = String(data: try JSONEncoder().encode(settings), encoding: .utf8)!
        
        self.library = try Library.default()
        
        guard let database = mongo_embedded_v1_instance_create(library.library, json, nil) else {
            fatalError()
        }
        
        guard let client = mongo_embedded_v1_client_create(database, nil) else {
            fatalError()
        }
        
        self.database = database
        self.client = client
        writeBuffer = allocator.buffer(capacity: 16_000_000)
        readBuffer = allocator.buffer(capacity: 16_000_000)
        
        super.init(eventLoop: group.next(), sessionManager: SessionManager())
    }
    
    private func _send(context: MongoDBCommandContext) -> EventLoopFuture<ServerReply> {
        do {
            if self.invalid {
                throw MobileError.invalidState
            }
            
            writeBuffer.clear()
            try serializer.encode(data: context, into: &writeBuffer)
        
            return try writeBuffer.withUnsafeReadableBytes { writeBuffer -> EventLoopFuture<ServerReply> in
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
                
                let buffer = UnsafeRawBufferPointer(start: readPointer!, count: readCount)
                self.readBuffer.write(bytes: buffer)
                let result = try deserializer.parse(from: &readBuffer)
                
                guard result == .continue, let reply = deserializer.reply else {
                    throw MobileError.invalidState
                }
                
                readBuffer.clear()
                return eventLoop.newSucceededFuture(result: reply)
            }
        } catch {
            self.invalid = true
            return eventLoop.newFailedFuture(error: error)
        }
    }
    
    override func send<C>(command: C, session: ClientSession? = nil, transaction: TransactionQueryOptions? = nil) -> EventLoopFuture<ServerReply> where C : MongoDBCommand {
        let context = MongoDBCommandContext(
            command: command,
            requestID: 0,
            retry: true,
            session: session,
            transaction: transaction,
            promise: self.eventLoop.newPromise()
        )
        
        return _send(context: context)
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
