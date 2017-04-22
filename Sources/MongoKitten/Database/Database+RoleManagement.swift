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

extension Database {
    
    /// Grants roles to a user in this database
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/grantRolesToUser/#dbcmd.grantRolesToUser
    ///
    /// TODO: Easier roleList creation
    ///
    /// - parameter roleList: The roles to grants
    /// - parameter user: The user to grant the roles to
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func grant(roles roleList: Document, to user: String) throws {
        let command: Document = [
            "grantRolesToUser": user,
            "roles": roleList
        ]
        
        log.verbose("Granting roles to user \"\(user)\"")
        log.debug(roleList)

        let document = try firstDocument(in: try execute(command: command))

        guard Int(document["ok"]) == 1 else {
            log.error("grantRolesToUser for user \"\(user)\" was not successful because of the following error")
            log.error(document)
            log.error("grantRolesToUser failed with the following roles")
            log.error(roleList)
            throw MongoError.commandFailure(error: document)
        }
    }
}
