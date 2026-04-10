import Tracing
import MongoClient

extension MongoDatabase {
    public func buildInfo() async throws -> BuildInfo {
        struct Request: Codable, Sendable {
            let buildInfo: Int
        }
        let request = Request(buildInfo: 1)
        let namespace = MongoNamespace(to: "$cmd", inDatabase: self.name)
        let connection = try await pool.next(for: .basic)
        let buildInfoSpan: any Span
        if let context {
            buildInfoSpan = InstrumentationSystem.tracer.startAnySpan(
                "BuildInfo<\(namespace)>",
                context: context
            )
        } else {
            buildInfoSpan = InstrumentationSystem.tracer.startAnySpan(
                "BuildInfo<\(namespace)>"
            )
        }
        let response = try await connection.executeCodable(
            request,
            decodeAs: BuildInfo.self,
            namespace: namespace,
            sessionId: nil,
            logMetadata: logMetadata,
            traceLabel: "BuildInfo<\(namespace)>",
            serviceContext: buildInfoSpan.context
        )
        return response
    }
}
