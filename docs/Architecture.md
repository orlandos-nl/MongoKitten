# MongoKitten Architecture

## Key decisions

- BSON is parsed using [our own BSON library](https://github.com/OpenKitten/BSON)
- ExtendedJSON is supported, but not a core part of MongoKitten or BSON. It is provided as a separate package.
- MongoKitten is fully async starting from version 5
- The sync API is to be built upon the async API
- Async support is built on Swift NIO
- TCP and SSL are handled by NIO
- Connections are managed by the user. We do not provide a connection pool
- The target audience are application developers. This means that we, for now, do not include helpers for management tasks, like adding database users. This may be added later upon request.
- Supported and tested target platforms are: macOS, Ubuntu versions supported by the Swift team, iOS
- Swift compiler requirement: 4.1
- MongoDB support: >=3.2. MongoKitten should perform feature detection and throw errors when trying operations that are not supported by the server.
- Protocol support: both the new (MongoDB 3.6) and conventional wire protocol are supported. MongoKitten selects the best protocol automatically and transparently.
- The only used & supported package manager is SPM, due to the increased maintenance costs of supporting a second package manager like Cocoapods
- In addition to the specific MongoKitten tests, we also test according to the [MongoDB specifications](https://github.com/mongodb/specifications)
- Codable: where applicable, Codable is used for encoding/decoding low and high level structures, including the core mongodb protocol implementation
- We support only 64-bit platforms, both big and little endian
- MongoKitten is not an ORM, but may be the foundation for one

## Reference Materials

- [The BSON specification](http://bsonspec.org)
- [MongoDB specifications](https://github.com/mongodb/specifications)
- [The MongoDB Wire Protocol](https://docs.mongodb.com/manual/reference/mongodb-wire-protocol/)
- [Swift NIO](https://github.com/apple/swift-nio) - their readme contains an excellent high level overview of the core concepts

## Layered Architecture

MongoKitten is based on a layered API architecture, where a user can access or interact with different parts of the MongoKitten API. More high level APIs provided by MongoKitten are built on the lower level APIs.

- Connection: handles the low-level TCP connection to a MongoDB server, authentication, and the MongoDB wire protocol implementation
- Database API: provides a higher-level API to communicate with a database over a connection. Allows executing commands
- Collection API: provides access to common operations on MongoDB collections, like executing CRUD operations

Users can interact with all these layers. For example, if the user is only interested in a single collection, they could initialise it using a connection string pointing to the specific collection. On a lower level, they can also choose to initialise a connection themselves.