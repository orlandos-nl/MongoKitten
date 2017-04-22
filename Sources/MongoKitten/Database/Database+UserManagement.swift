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
    /// Creates a new user
    ///
    /// Warning: Use an SSL socket to create someone for security sake!
    /// Warning: The standard library doesn't have SSL
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/createUser/#dbcmd.createUser
    ///
    /// TODO: Easier role creation
    ///
    /// - parameter user: The user's username
    /// - parameter password: The plaintext password
    /// - parameter roles: The roles document as specified in the additional information
    /// - parameter customData: The optional custom information to store
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func createUser(_ user: String, password: String, roles: Document, customData: Document? = nil) throws {
        var command: Document = [
            "createUser": user,
            "pwd": password,
            ]

        if let data = customData {
            command["customData"] = data
        }
        
        log.verbose("Creating user \(user)")
        log.debug(roles)

        command["roles"] = roles

        let reply = try execute(command: command)
        let document = try firstDocument(in: reply)

        guard Int(document["ok"]) == 1 else {
            log.error("createUser was not successful for user \(user) because of the following error")
            log.error(document)
            log.error("createUser had the following roiles and customData provided")
            log.error(roles)
            log.error(customData ?? [:])
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Updates a user in this database with a new password, roles and optional set of custom data
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/updateUser/#dbcmd.updateUser
    ///
    /// - parameter username: The user to update
    /// - parameter password: The user's new password
    /// - parameter roles: The roles to grant
    /// - parameter customData: The optional custom data to apply to the user
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func update(user username: String, password: String, roles: Document, customData: Document? = nil) throws {
        var command: Document = [
            "updateUser": username,
            "pwd": password,
            ]

        if let data = customData {
            command["customData"] = data
        }

        command["roles"] = roles

        let document = try firstDocument(in: try execute(command: command))

        guard Int(document["ok"]) == 1 else {
            log.error("updateUser was not successful for user \(username) because of the following error")
            log.error(document)
            log.error("updateUser had the following roles and customData")
            log.error(roles)
            log.error(customData ?? [:])
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Removes the specified user from this database
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/dropUser/#dbcmd.dropUser
    ///
    /// - parameter username: The username of the user to drop
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func drop(user username: String) throws {
        let command: Document = [
            "dropUser": username
        ]

        let document = try firstDocument(in: try execute(command: command))

        guard Int(document["ok"]) == 1 else {
            log.error("dropUser was not successful for user \(username) because of the following error")
            log.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Removes all users from this database
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/dropAllUsersFromDatabase/#dbcmd.dropAllUsersFromDatabase
    ///
    /// - throws: When unable to send the request/receive the response, the authenticated user doesn't have sufficient permissions or an error occurred
    public func dropAllUsers() throws {
        let command: Document = [
            "dropAllUsersFromDatabase": Int32(1)
        ]

        let document = try firstDocument(in: try execute(command: command))

        guard Int(document["ok"]) == 1 else {
            log.error("dropAllUsersFromDatabase was not successful because of the following error")
            log.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }
}
