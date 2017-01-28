//
//  SSLSettings.swift
//  MongoKitten
//
//  Created by Laurent Gaches on 28/01/2017.
//
//

import Foundation
import TLS

/// Settings for connecting to MongoDB via SSL.
public struct SSLSettings: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.enabled = value
        self.invalidHostNameAllowed = false
        self.invalidCertificateAllowed = false
    }

    /// The certificate repository to use. This repository contains the root certificates for all trusted CAs.
//    public var certificates: Certificates = .openbsd

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
