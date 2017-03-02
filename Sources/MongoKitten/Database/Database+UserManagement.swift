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
    /// - parameter user: The user's username
    /// - parameter password: The plaintext password
    /// - parameter roles: The roles document as specified in the additional information
    /// - parameter customData: The optional custom information to store
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func createUser(_ user: String, password: String, roles: Document, customData: Document? = nil) throws {
        var command: Document = [
            "createUser": user,
            "pwd": password,
            ]

        if let data = customData {
            command["customData"] = data
        }

        command["roles"] = roles

        let reply = try execute(command: command)
        let document = try firstDocument(in: reply)

        guard document["ok"] as Int? == 1 else {
            logger.error("createUser was not successful for user \(user) because of the following error")
            logger.error(document)
            logger.error("createUser had the following roiles and customData provided")
            logger.error(roles)
            logger.error(customData ?? [:])
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Updates a user in this database with a new password, roles and optional set of custom data
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/updateUser/#dbcmd.updateUser
    ///
    /// - parameter user: The user to udpate
    /// - parameter password: The new password
    /// - parameter roles: The roles to grant
    /// - parameter customData: The optional custom data you'll give him
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
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

        guard document["ok"] as Int? == 1 else {
            logger.error("updateUser was not successful for user \(username) because of the following error")
            logger.error(document)
            logger.error("updateUser had the following roles and customData")
            logger.error(roles)
            logger.error(customData ?? [:])
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Removes the specified user from this database
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/dropUser/#dbcmd.dropUser
    ///
    /// - parameter user: The username from the user to drop
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func drop(user username: String) throws {
        let command: Document = [
            "dropUser": username
        ]

        let document = try firstDocument(in: try execute(command: command))

        guard document["ok"] as Int? == 1 else {
            logger.error("dropUser was not successful for user \(username) because of the following error")
            logger.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }

    /// Removes all users from this database
    ///
    /// For additional information: https://docs.mongodb.com/manual/reference/command/dropAllUsersFromDatabase/#dbcmd.dropAllUsersFromDatabase
    ///
    /// - throws: When we can't send the request/receive the response, you don't have sufficient permissions or an error occurred
    public func dropAllUsers() throws {
        let command: Document = [
            "dropAllUsersFromDatabase": Int32(1)
        ]

        let document = try firstDocument(in: try execute(command: command))

        guard document["ok"] as Int? == 1 else {
            logger.error("dropAllUsersFromDatabase was not successful because of the following error")
            logger.error(document)
            throw MongoError.commandFailure(error: document)
        }
    }
}
