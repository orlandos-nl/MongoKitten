//
//  BuildInfo.swift
//  MongoKitten
//
//  Created by Mykola Buhaiov on 10.04.2026.
//

import BSON

public struct BuildInfo: Decodable, Sendable {
    public let version: String
    public let versionArray: [Int]
    public let gitVersion: String
    public let modules: [String]
    public let allocator: String?
    public let javascriptEngine: String?
    public let sysinfo: String?
    public let openssl: OpenSSLInfo?
    public let buildEnvironment: BuildEnvironment?
    public let bits: Int
    public let debug: Bool
    public let maxBsonObjectSize: Int64
    public let storageEngines: [String]
    public let ok: Int
}

public struct OpenSSLInfo: Decodable, Sendable {
    public let running: String
    public let compiled: String
}

public struct BuildEnvironment: Decodable, Sendable {
    public let distmod: String?
    public let distarch: String?
    public let cc: String?
    public let ccflags: String?
    public let cxx: String?
    public let cxxflags: String?
    public let linkflags: String?
    public let target_arch: String?
    public let target_os: String?
    public let cppdefines: String?
}
