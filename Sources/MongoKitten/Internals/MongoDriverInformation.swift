//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of MongoKitten project authors
//

import Foundation

/// MongoDriverInformation allows to add extra information about the driver. This information is then available in the MongoD/MongoS logs.
///
/// - SeeAlso : https://github.com/mongodb/specifications/blob/master/source/mongodb-handshake/handshake.rst
struct MongoDriverInformation: ValueConvertible {

    /// Application Name
    let appName: String?

    /// Converts this to an embeddable BSONPrimitive
    public func makeBSONPrimitive() -> BSONPrimitive {

        let driver: Document = ["name":"MongoKitten","version":"3.1.5"]


        var client: Document = ["driver": driver]


        if client.byteCount < 512 {
            #if os(Linux)
                var os: Document = ["type":"Linux"]
            #else
                var os: Document = ["type":"Darwin"]
            #endif

            if ProcessInfo.processInfo.operatingSystemVersion.majorVersion != -1 {
                os.append("\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.patchVersion)", forKey: "version")
            }

            client.append(os, forKey: "os")
        }

        if let appName = appName, appName.lengthOfBytes(using: .utf8) < 128 && client.byteCount < 512  {
            let application: Document = ["name":appName]
            client.append(application, forKey: "application")
        }

        return client
    }
}
