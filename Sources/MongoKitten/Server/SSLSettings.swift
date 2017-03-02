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

/// Settings for connecting to MongoDB via SSL.
public struct SSLSettings: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.enabled = value
        self.invalidHostNameAllowed = false
        self.invalidCertificateAllowed = false
    }

    /// Enable SSL
    public let enabled: Bool

    /// Invalid host names should be allowed. Defaults to false. Take care before setting this to true, as it makes the application susceptible to man-in-the-middle attacks.
    public let invalidHostNameAllowed: Bool

    /// Invalis certificate should be allowed. Defaults to false. Take care before setting this to true, as it makes the application susceptible to man-in-the-middle attacks.
    public let invalidCertificateAllowed: Bool

    /// Creates an SSLSettings specification
    public init(enabled: Bool, invalidHostNameAllowed: Bool = false, invalidCertificateAllowed: Bool = false) {
        self.enabled = enabled
        self.invalidHostNameAllowed = invalidHostNameAllowed
        self.invalidCertificateAllowed = invalidCertificateAllowed
    }
}
