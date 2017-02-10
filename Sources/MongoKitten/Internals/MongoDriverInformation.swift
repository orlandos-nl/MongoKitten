//
// This source file is part of the MongoKitten open source project
//
// Copyright (c) 2016 - 2017 OpenKitten and the MongoKitten project authors
// Licensed under MIT
//
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/LICENSE.md for license information
// See https://github.com/OpenKitten/MongoKitten/blob/mongokitten31/CONTRIBUTORS.md for the list of Swift project authors
//

import Foundation


/// MongoDriverInformation allows to add extra information about the driver. This information is then available in the MongoD/MongoS logs.
///
/// - SeeAlso : https://github.com/mongodb/specifications/blob/master/source/mongodb-handshake/handshake.rst
struct MongoDriverInformation: ValueConvertible {

    /// Driver Name
    let name: String

    /// Driver Version
    let version: String

    /// OS Name
    let osName: String

    /// OS Architecture
    let architecture: String

    /// Application Name
    let appName: String?

    /// Converts this to an embeddable BSONPrimitive
    public func makeBSONPrimitive() -> BSONPrimitive {

        let driver: Document = ["name":"MongoKitten","version":"3.1.0"]


        var client: Document = ["driver": driver]

        if client.byteCount < 512 {
            #if os(Linux)
                let os: Document = ["type":"Linux"]
            #else
                let os: Document = ["type":"Darwin"]
            #endif
            client.append(os, forKey: "os")
        }

        if let appName = appName, appName.lengthOfBytes(using: .utf8) < 128 && client.byteCount < 512  {
            let application: Document = ["name":appName]
            client.append(application, forKey: "application")
        }

        return client
    }
}
