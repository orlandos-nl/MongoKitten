# MongoKitten 5

[MongoKitten](https://github.com/OpenKitten/MongoKitten) is a pure swift, [high performance](performance.md) driver for [MongoDB](https://mongodb.com).
It aims to provide high and low level APIs alike, allowing control for power users and and simple APIs for regular users.
It comes with [BSON](bson.md), a performant library that allows creation and modification with MongoDB's primitives in a native API.

For more high-level APIs we support the [Meow ORM](https://github.com/OpenKitten/Meow). This allows you to define models and migrations with minimal code and supports writing type-safe queries.

### Differences with MongoKitten 4

The main difference between MongoKitten 4 and 5 is the change from synchronous to asynchronous. This was an important change with the rise of Swift-NIO in the Server Side Swift community. We strongly that Swift-NIO based drivers are the right choice when writing a database driver in Swift because it improves stability and performance whilst reducing the complexity.

Aside from that we removed a lot of little used functions and function parameters to reduce the API complexity.

[Read the full changelog](4-to-5-changelog.md)

## Features

MongoKitten 5 supports almost every feature MongoDB has to offer, and is architecturally ready for the rest.

### Supported features

- [Aggregates](aggregates.md)
- [Authentication](https://docs.mongodb.com/manual/reference/connection-string/)
    - Automatic selection
    - SCRAM_SHA_1
    - SCRAM_SHA_256
- Administrative commands
    - Drop
    - Create Indexes
- [Codable (Encoding/Decoding)](bson-codable.md)
    - [Many strategies options for encoding/decoding](bson-codable-settings.md)
- [Cursor transformations](cursor.md)
- Custom commands for unsupported (administrative) operations
- CRUD operations
    - Create, Read, Count, Distinct, Update, Upsert, Delete
    - Including bulk APIs
- [Change streams](change-streams.md)
- [GridFS](gridfs.md)
- [SSL with SNI verification](https://docs.mongodb.com/manual/reference/connection-string/)
- Session APIs
- [Queries](queries.md)
    - Raw queries (Document)
    - Operator based query builder
    - Sorting
    - Projections

### Features awaiting implementation

All features marked in bold will be picked up _before_ the final 5.0 release. Other features will be deferred until later updates.

- **Automatic server reconnection (WIP)**
- **Automatic server selection (WIP)**
- Aggregate pipelines with type-safety
- Casual consistency
- Collations
- **Cluster support (WIP)**
- Custom root certificates for SSL
- **Decimal128**
- **Improved index APIs**
- **MongoDB SRV record based server discovery (WIP, [almost done](https://github.com/OpenKitten/NioDNS))**
- **Server Discovery and Monitoring (WIP)**
- MongoDB-CR authentication (legacy)
- Multi-document transactions
- Optional protocol checksum and full document validation
- Read concerns
- Streaming GridFS APIs
- Write concerns
- X509, certificate based authentication
- ZLib compression

## Separation of APIs

MongoKitten's APIs are categorised in 2 groups, the commands and the helpers.

Whenever you execute a query from the Collection or Database objects this is a helper. The internal implementation of a helper is always derived from the Commands APIs.

A command can have many parameters. Some of these parameters are always necessary whilst other parameters are only necessary in a handful of scenario's. These parameters that are often not used are only available in the Commands API and don't exist in the helpers at all. This is done to simplify the simple APIs. For this reason, you'll need to use the Commands API yourself for more specific tasks.

If you want to learn more about a command, the easiest thing you can do it so open the related helper and the command struct.

```Swift
let command = CountCommand(in: usersCollection)
```

When your command is configured you can simply all the `execute` function on this command. If you use a specific set of advanced parameters throughout your application, please consider putting them in an [extension](https://docs.swift.org/swift-book/LanguageGuide/Extensions.html) instead. This will greatly simplify your codebase.

## Why?

When we started this project, Server Side Swift was in the first month of existence with projects like Zewo, Kitura and Vapor just starting up or not even being created. As you might imagine, the need for database drivers was not fulfilled yet. Once we started looking into a MongoDB driver there was one library which was wrapping the official C library but had trouble creating an API that felt like it belonged within the Swift ecosystem.

After this experience we set out to create our own tooling, but ran into the same API complexities. C and Swift are fundamentally different languages, with one big Swift-specific feature being protocols. Since then, MongoDB has started their own implementation based on their C library and aim to create an API that feels like Swift. There are, however, big challenges here that are (almost) impossible for MongoDB to resolve. [More about differences with MongoDB's official driver.](official-driver.md)

Our projects' lifespans have been really successful with great community feedback and support.
