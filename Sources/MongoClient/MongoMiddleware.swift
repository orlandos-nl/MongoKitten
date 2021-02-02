//import MongoCore
//
//public protocol MongoMiddleware {
//    func onRequest(_ request: inout MongoMiddlewareRequest, inContext: MongoMiddlewareContext)
//    func onResponse(_ response: inout MongoMiddlewareResponse, inContext: MongoMiddlewareContext)
//}
//
//public struct MongoMiddlewareRequest {
//    public var command: MongoClientRequest
//}
//
//public struct MongoMiddlewareResponse {
//    public var response: MongoServerReply
//}
//
///// This context is only to be used in the ephemeral context of a middleware function
///// Results _derived_ from this contexts can be kept for longer
//public struct MongoMiddlewareContext {
//    /// Guaranteed to be non-nil in a middleware context. Do not keep this context lingering for
//    public private(set) unowned var connection: MongoConnection!
//    public private(set) weak var cluster: MongoCluster?
//}
