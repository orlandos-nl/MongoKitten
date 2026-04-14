import MongoClient

extension MongoDatabase {
    /// Returns detailed build information about the MongoDB server instance.
    ///
    /// This method executes the MongoDB [`buildInfo`](https://www.mongodb.com/docs/manual/reference/command/buildInfo/)
    /// command and decodes the response into a strongly typed `BuildInfo` model.
    ///
    /// The returned information includes version, git commit, build environment,
    /// storage engines, OpenSSL details, and other server build metadata.
    ///
    /// - Returns: A `BuildInfo` structure containing server build metadata.
    /// - Throws: An error if the command execution fails or decoding fails.
    public func buildInfo() async throws -> BuildInfo {
        struct Request: Codable, Sendable {
            let buildInfo: Int
        }

        let request = Request(buildInfo: 1)
        let namespace = MongoNamespace(to: "$cmd", inDatabase: self.name)

        let connection = try await pool.next(for: .basic)
        let response = try await connection.executeCodable(
            request,
            decodeAs: BuildInfo.self,
            namespace: namespace,
            sessionId: nil,
            logMetadata: logMetadata,
            traceLabel: "BuildInfo<\(namespace)>",
            serviceContext: nil
        )
        return response
    }
}

/// Result of MongoDB `buildInfo` command.
/// Provides detailed information about the running MongoDB instance build.
public struct BuildInfo: Decodable, Sendable {
    /// Human-readable version string of MongoDB instance.
    /// Preferred for display purposes.
    public let version: String
    /// Version represented as an array of integers:
    /// `[major, minor, patch, ...]`.
    public let versionArray: [Int]
    /// Git commit hash of the MongoDB source used for this build.
    public let gitVersion: String
    /// List of modules included in the build (e.g. `"enterprise"`).
    public let modules: [String]
    /// Memory allocator used by MongoDB (e.g. `"tcmalloc"`).
    /// Optional and considered unstable/internal.
    public let allocator: String?
    /// JavaScript engine used by MongoDB (default: `"mozjs"`).
    public let javascriptEngine: String?
    /// System information string (if provided by server build).
    public let sysinfo: String?
    /// OpenSSL / TLS library information used by MongoDB.
    public let openssl: OpenSSLInfo?
    /// Detailed build environment information (compiler, OS, flags, etc.).
    public let buildEnvironment: BuildEnvironment?
    /// Target architecture bitness (e.g. 64).
    public let bits: Int
    /// Indicates whether MongoDB was built in debug mode.
    public let debug: Bool
    /// Maximum BSON document size supported by the server.
    public let maxBsonObjectSize: Int64
    /// List of available storage engines (e.g. `["wiredTiger"]`).
    public let storageEngines: [String]
    /// Command status field (typically `1` for success).
    public let ok: Int
}

/// Build environment metadata captured at compile time.
public struct BuildEnvironment: Decodable, Sendable {
    /// Distribution modifier (e.g. `enterprise`, `amzn`, etc.)
    public let distmod: String?
    /// Architecture used for distribution build (e.g. `x86_64`).
    public let distarch: String?
    /// C compiler used to build MongoDB.
    public let cc: String?
    /// C compiler flags.
    public let ccflags: String?
    /// C++ compiler used to build MongoDB.
    public let cxx: String?
    /// C++ compiler flags.
    public let cxxflags: String?
    /// Linker flags used during build.
    public let linkflags: String?
    /// Target CPU architecture.
    public let target_arch: String?
    /// Target operating system.
    public let target_os: String?
    /// Preprocessor definitions used during build.
    public let cppdefines: String?
}

/// OpenSSL / TLS runtime + compile-time versions.
public struct OpenSSLInfo: Decodable, Sendable {
    /// OpenSSL version currently running.
    public let running: String
    /// OpenSSL version used at compile time.
    public let compiled: String
}
