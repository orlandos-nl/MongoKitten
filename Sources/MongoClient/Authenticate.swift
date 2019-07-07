import _MongoKittenCrypto
import Foundation
import MongoCore
import NIO

extension MongoConnection {
    func authenticate(to source: String, with credentials: ConnectionSettings.Authentication) -> EventLoopFuture<Void> {
        let namespace = MongoNamespace(to: "$cmd", inDatabase: source)

        var credentials = credentials

        if case .auto(let user, let pass) = credentials {
            do {
                credentials = try selectAuthenticationAlgorithm(forUser: user, password: pass)
            } catch {
                return eventLoop.makeFailedFuture(error)
            }
        }

        switch credentials {
        case .unauthenticated:
            return eventLoop.makeSucceededFuture(())
        case .auto(let username, let password):
            if let mechanisms = serverHandshake!.saslSupportedMechs {
                nextMechanism: for mechanism in mechanisms {
                    switch mechanism {
                    case "SCRAM-SHA-1":
                        return self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
                    case "SCRAM-SHA-256":
                        // TODO: Enforce minimum 4096 iterations
                        return self.authenticateSASL(hasher: SHA256(), namespace: namespace, username: username, password: password)
                    default:
                        continue nextMechanism
                    }
                }

                return eventLoop.makeFailedFuture(MongoAuthenticationError(reason: .unsupportedAuthenticationMechanism))
            } else if serverHandshake!.maxWireVersion.supportsScramSha1 {
                return self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
            } else {
                return self.authenticateCR(username, password: password, namespace: namespace)
            }
        case .scramSha1(let username, let password):
            return self.authenticateSASL(hasher: SHA1(), namespace: namespace, username: username, password: password)
        case .scramSha256(let username, let password):
            return self.authenticateSASL(hasher: SHA256(), namespace: namespace, username: username, password: password)
        case .mongoDBCR(let username, let password):
            return self.authenticateCR(username, password: password, namespace: namespace)
        }
    }

    public func selectAuthenticationAlgorithm(forUser user: String, password: String) throws -> ConnectionSettings.Authentication {
        guard let handshake = serverHandshake else {
            throw MongoAuthenticationError(reason: .missingServerHandshake)
        }
        
        if let saslSupportedMechs = handshake.saslSupportedMechs {
            nextMechanism: for mech in saslSupportedMechs {
                switch mech {
                case "SCRAM-SHA-256":
                    return .scramSha256(username: user, password: password)
                case "SCRAM-SHA-1":
                    return .scramSha1(username: user, password: password)
                default:
                    // Unknown algorithm
                    continue nextMechanism
                }
            }
        }

        if handshake.maxWireVersion.supportsScramSha1 {
            return .scramSha1(username: user, password: password)
        } else {
            return .mongoDBCR(username: user, password: password)
        }
    }
}

