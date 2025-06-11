<a href="https://unbeatable.software"><img src="./assets/Header.png" /></a>

<img src="./assets/Descriptions.gif" />

A fast, pure swift [MongoDB](https://mongodb.com) driver based on [Swift NIO](https://github.com/apple/swift-nio) built for Server Side Swift. It features a great API and a battle-tested core. Supporting both MongoDB in server and embedded environments.

MongoKitten is a fully asynchronous driver, which means that it doesn't block any threads. This also means that it can be used in any asynchronous environment, such as [Vapor](https://github.com/vapor/vapor) or [Hummingbird](https://github.com/hummingbird-project/hummingbird).

## Table of Contents

- [Docs \& Community](#docs--community)
    - [Projects](#projects)
- [Installation](#installation)
  - [Set up MongoDB server](#set-up-mongodb-server)
  - [Add MongoKitten to your Swift project 🚀](#add-mongokitten-to-your-swift-project-)
    - [Add Meow (Optional)](#add-meow-optional)
- [Basic usage](#basic-usage)
  - [Connect vs. LazyConnect](#connect-vs-lazyconnect)
  - [CRUD](#crud)
    - [Create](#create)
    - [Read](#read)
      - [Cursors](#cursors)
        - [Fetching results](#fetching-results)
        - [Cursors are generic](#cursors-are-generic)
    - [Update \& Delete](#update--delete)
  - [Indexes](#indexes)
  - [Aggregation](#aggregation)
  - [Transactions](#transactions)
  - [GridFS](#gridfs)
- [About BSON](#about-bson)
  - [Literals](#literals)
  - [Just Another Collection](#just-another-collection)
    - [Think twice before converting between `Document` and `Dictionary`](#think-twice-before-converting-between-document-and-dictionary)
  - [Codable](#codable)
- [Advanced Features](#advanced-features)
  - [Change Streams](#change-streams)
  - [Logging and Monitoring](#logging-and-monitoring)
  - [Best Practices](#best-practices)
    - [Connection Management](#connection-management)
    - [Performance Optimizations](#performance-optimizations)
- [Troubleshooting](#troubleshooting)
- [Meow ORM](#meow-orm)
  - [Setting up with Vapor](#setting-up-with-vapor)
  - [Setting up with Hummingbird](#setting-up-with-hummingbird)
  - [Models](#models)
    - [Queries](#queries)
    - [References](#references)
  - [Backers](#backers)

## Quick Start

Get up and running in under 5 minutes:

```swift
// Add to Package.swift
.package(url: "https://github.com/orlandos-nl/MongoKitten.git", from: "7.9.0")

// In your code
import MongoKitten

// Connect to database
let db = try await MongoDatabase.connect(to: "mongodb://localhost/my_database")

// Insert a document
try await db["users"].insert(["name": "Alice", "age": 30])

// Query documents
let users = try await db["users"].find("age" >= 18).drain()

// Use with Codable
struct User: Codable {
    let name: String
    let age: Int
}

let typedUsers = try await db["users"]
    .find()
    .decode(User.self)
    .drain()
```

### Key Requirements

- **Swift**: 5.5 or later (for async/await support)
- **MongoDB**: 3.6 or later
- **Platforms**: macOS, iOS, Linux

### Optional Features Requirements

- **Change Streams**: MongoDB 3.6+ (replica set or sharded cluster)
- **Transactions**: MongoDB 4.0+ (replica set or sharded cluster)

# Docs & Community

[Join our Discord](https://discord.gg/H6799jh) for any questions and friendly banter.

If you need hands-on support on your projects, our team is available at [joannis@unbeatable.software](mailto:joannis@unbeatable.software).

[Look into Sample Code](https://github.com/orlandos-nl/MongoKitten-Examples) using MongoKitten & Vapor

### Projects

A couple of MongoKitten based projects have arisen, check them out!

- [MongoQueue](https://github.com/orlandos-nl/MongoQueue)
- [Vapor's Fluent + MongoDB](https://github.com/vapor/fluent-mongo-driver)
- [MongoDB + Vapor Queues](https://github.com/vapor-community/queues-mongo-driver)

# Installation

## Set up MongoDB server

If you haven't already, you should set up a MongoDB server to get started with MongoKitten. MongoKitten supports MongoDB 3.6 and above.

For development, this can be on your local machine.

Install MongoDB for [Ubuntu](https://www.mongodb.com/docs/v6.0/tutorial/install-mongodb-on-ubuntu/), [macOS](https://www.mongodb.com/docs/v6.0/tutorial/install-mongodb-on-os-x/) or any other supported Linux Distro.

Alternatively, make use of a DAAS (Database-as-a-service) like [MongoDB Atlas](https://cloud.mongodb.com).

## Add MongoKitten to your Swift project 🚀

MongoKitten uses the [Swift Package Manager](https://swift.org/getting-started/#using-the-package-manager). Add MongoKitten to your dependencies in your **Package.swift** file:

`.package(url: "https://github.com/orlandos-nl/MongoKitten.git", from: "7.9.0")`

Also, don't forget to add the product `"MongoKitten"` as a dependency for your target.

```swift
.product(name: "MongoKitten", package: "MongoKitten"),
```

### Add Meow (Optional)

Meow is an ORM that resides in this same package.

```swift
.product(name: "Meow", package: "MongoKitten"),
```

# Basic usage

First, connect to a database:

```swift
import MongoKitten

let db = try await MongoDatabase.connect(to: "mongodb://localhost/my_database")
```

Vapor users only should register the database as service:
```swift
extension Request {
    public var mongo: MongoDatabase {
        return application.mongo.adoptingLogMetadata([
            "request-id": .string(id)
        ])
    }
}

private struct MongoDBStorageKey: StorageKey {
    typealias Value = MongoDatabase
}

extension Application {
    public var mongo: MongoDatabase {
        get {
            storage[MongoDBStorageKey.self]!
        }
        set {
            storage[MongoDBStorageKey.self] = newValue
        }
    }
    
    public func initializeMongoDB(connectionString: String) throws {
        self.mongo = try MongoDatabase.lazyConnect(to: connectionString)
    }
}
```
Make sure to instantiate the database driver before starting your application.
```
try app.initializeMongoDB(connectionString: "mongodb://localhost/my-app")
```


## Connect vs. LazyConnect

In MongoKitten, you'll find two main variations of connecting to MongoDB.

- `connect` calls are `async throws`, and will _immediately_ attempt to establish a connection. These functions throw an error if unsuccessful.
- `lazyConnect` calls are `throws`, and will defer establishing a connection until it's necessary. Errors are only thrown if the provided credentials are unusable.

Connect's advantage is that a booted server is known to have a connection. Any issues with MongoBD will arise _immediately_, and the error is easily inspectable.

LazyConnect is helpful during development, because connecting to MongoDB can be a time-consuming process in certain setups. LazyConnect allows you to start working with your system almost immediately, without waiting for MongoKitten. Another advantage is that cluster outages or offly timed topology changes do not influence app boot. Therefore, MongoKitten can simply attempt to recover in the background. However, should something go wrong it can be hard to debug this.

## CRUD

Before doing operations, you need access to a collection where you store your models. This is MongoDB's equivalent to a table.

```swift
// The collection "users" in your database
let users = db["users"]
```

### Create

```swift
// Create a document to insert
let myUser: Document = ["username": "kitty", "password": "meow"]

// Insert the user into the collection
// The _id is automatically generated if it's not present
try await users.insert(myUser)
```

### Read

To perform the following query in MongoDB:

```json
{
  "username": "kitty"
}
```

Use the following MongoKitten code:

```swift
if let kitty = try await users.findOne("username" == "kitty") {
  // We've found kitty!
}
```

To perform the following query in MongoDB:

```json
{
  "$or": [
    { "age": { "$lte": 16 } },
    { "age": { "$exists": false } }
  ]
}
```

Use the following MongoKitten code:

```swift
for try await user in users.find("age" <= 16 || "age" == nil) {
  // Asynchronously iterates over each user in the cursor
}
```

You can also type out the queries yourself, without using the query builder, like this:

```swift
// This is the same as the previous example
users.findOne(["username": "kitty"])
```

#### Cursors

Find operations return a `Cursor`. A cursor is a pointer to the result set of a query. You can obtain the results from a cursor by iterating over the results, or by fetching one or all of the results.

Cursors will close automatically if the enclosing `Task` is cancelled.

##### Fetching results

You can fetch all results as an array:

```swift
// Fetch all results and collect them in an array
let users = try await users.find().drain()
```

Note that this is potentially dangerous with very large result sets. Only use `drain()` when you are sure that the entire result set of your query fits comfortably in memory.

##### Cursors are generic

Find operations return a `FindQueryBuilder`. You can lazily transform this (and other) cursors into a different result type by using `map`, which works similar to `map` on arrays or documents. A simple commonly used helper based on map is `.decode(..)` which decodes each result Document into a `Decodable` entity of your choosing.

```swift
let users: [User] = try await users.find().decode(User.self).drain()
```

### Update & Delete

You can do update and delete entities the same way you'd see in the MongoDB docs.

```swift
try await users.updateMany(where: "username" == "kitty", setting: ["age": 3], unsetting: nil)
```

The result is implicitly discarded, but you can still get and use it.

```swift
try await users.deleteOne(where: "username" == "kitty")

let reply = try await users.deleteAll(where: "furType" == "fluffy")
print("Deleted \(reply.deletes) kitties 😿")
```

## Indexes

You can create indexes on a collection using the `buildIndexes` method.

```swift
try await users.buildIndexes {
  // Unique indexes ensure that no two documents have the same value for a field
  // See https://docs.mongodb.com/manual/core/index-unique/s
  UniqueIndex(
    named: "unique-username", 
    field: "username"  
  )

  // Text indexes allow you to search for documents using text
  // See https://docs.mongodb.com/manual/text-search/
  TextScoreIndex(
    named: "search-description", 
    field: "description"
  )

  // TTL Indexes expire documents after a certain amount of time
  // See https://docs.mongodb.com/manual/core/index-ttl/
  TTLIndex(
    named: "expire-createdAt", 
    field: "createdAt", 
    expireAfterSeconds: 60 * 60 * 24 * 7 // 1 week
  )
}
```

## Aggregation

MongoDB supports aggregation pipelines. You can use them like this:

```swift
let pipeline = try await users.buildAggregate {
  // Match all users that are 18 or older
  Match(where: "age" >= 18)

  // Sort by age, ascending
  Sort(by: "age", direction: .ascending)

  // Limit the results to 3
  Limit(3)
}

// Pipeline is a cursor, so you can iterate over it
// This will iterate over the first 3 users that are 18 or older in ascending age order
for try await user in pipeline {
  // Do something with the user
}
```

## Transactions


Execute multiple operations atomically:

```swift
try await db.transaction { session in
    let users = db["users"]
    let accounts = db["accounts"]
    
    try await users.insert(newUser)
    try await accounts.insert(newAccount)
    
    // Changes are only committed if no errors occur
}
```

## GridFS

MongoKitten supports GridFS. You can use it like this:

```swift
let database: MongoDatabase = ...
let gridFS = GridFSBucket(in: database)
```

You can then use the GridFSBucket to upload and download files.

```swift
let blob: ByteBuffer = ...
let file = try await gridFS.upload(
  blob,
  filename: "invoice.pdf",
  metadata: [
    "invoiceNumber": 1234,
    "invoiceDate": Date(),
    "invoiceAmount": 123.45
  ]
)
```

Optionally, you can define a custom chunk size. The default is 255kb.

For chunked file uploads, you can use the `GridFSFileWriter`:

```swift
let writer = GridFSFileWriter(toBucket: gridFS)

do {
  // Stream the file from HTTP
  for try await chunk in request.body {
    // Assuming `chunk is ByteBuffer`
    // Write each HTTP chunk to GridFS
    try await writer.write(data: chunk)
  }

  // Finalize the file, making it available for reading
  let file = try await writer.finalize(filename: "invoice.pdf", metadata: ["invoiceNumber": 1234])
} catch {
  // Clean up written chunks, as the file upload failed
  try await writer.cancel()

  // rethrow original error
  throw error
}
```

You can read the file back using the `GridFSReader` or by iterating over the `GridFSFile` as an `AsyncSequence`:

```swift
// Find your file in GridFS
guard let file = try await gridFS.findFile("metadata.invoiceNumber" == 1234) else {
  // File does not exist
  throw Abort(.notFound)
}

// Get all bytes in one contiguous buffer
let bytes = try await file.reader.readByteBuffer()

// Stream the file
for try await chunk in file {
  // `chunk is ByteBuffer`, now do something with the chunk!
}
```

# About BSON

MongoDB is a document database that uses BSON under the hood to store JSON-like data. MongoKitten implements the [BSON specification](http://bsonspec.org) in its companion project, [OpenKitten/BSON](https://github.com/OpenKitten/BSON). You can find out more about our BSON implementation in the separate BSON repository, but here are the basics:

## Literals

You normally create BSON Documents like this:

```swift
let documentA: Document = ["_id": ObjectId(), "username": "kitty", "password": "meow"]
let documentB: Document = ["kitty", 4]
```

From the example above, we can learn a few things:

- A BSON document can represent an array *or* a dictionary
- You can initialize a document like you initialize normal dictionaries and arrays, using literals
- The values in a Document (either the array elements or the values of a dictionary pair) can be of any BSON primitive type
- BSON primitives include core Swift types such as `Int`, `String`, `Double` and `Bool`, as well as `Date` from Foundation
- BSON also features some unique types, such as `ObjectId`

## Just Another Collection

Like normal arrays and dictionaries, `Document` conforms to the `Collection` protocol. Because of this, you can often directly work with your `Document`, using the APIs you already know from `Array` and `Dictionary`. For example, you can iterate over a document using a for loop:

```swift
for (key, value) in documentA {
	// ...
}

for value in documentB.values {
	// ...
}
```

Document also provides subscripts to access individual elements. The subscripts return values of the type `Primitive?`, so you probably need to cast them using `as?` before using them.

```swift
let username = documentA["username"] as? String
```

### Think twice before converting between `Document` and `Dictionary`

Our `Document` type is implemented in an optimized, efficient way and provides many useful features to read and manipulate data, including features not present on the Swift `Dictionary` type. On top of that, `Document` also implements most APIs present on `Dictionary`, so there is very little learning curve.

## Codable

MongoKitten supports the `Encodable` and `Decodable` (`Codable`) protocols by providing the `BSONEncoder` and `BSONDecoder` types. Working with our encoders and decoders is very similar to working with the Foundation `JSONEncoder` and `JSONDecoder` classes, with the difference being that `BSONEncoder` produces instances of `Document` and `BSONDecoder` accepts instances of `Document`, instead of `Data`.

For example, say we want to code the following struct:

```swift
struct User: Codable {
	var profile: Profile?
	var username: String
	var password: String
	var age: Int?
	
	struct Profile: Codable {
		var profilePicture: Data?
		var firstName: String
		var lastName: String
	}
}
```

We can encode and decode instances like this:

```swift
let user: User = ...

let encoder = BSONEncoder()
let encoded: Document = try encoder.encode(user)

let decoder = BSONDecoder()
let decoded: User = try decoder.decode(User.self, from: encoded)
```

A few notes:

- `BSONEncoder` and `BSONDecoder` work very similar to other encoders and decoders
- Nested types can also be encoded and are encouraged
	- Nested structs and classes are most often encoded as embedded documents
- You can customize the representations using encoding/decoding strategies

# Advanced Features

## Change Streams

MongoKitten provides powerful support for MongoDB Change Streams, allowing you to monitor real-time changes to your collections:

```swift
// Basic change stream usage
let stream = try await users.watch()

for try await change in stream {
    switch change.operationType {
    case .insert:
        print("New document: \(change.fullDocument)")
    case .update:
        print("Updated fields: \(change.updateDescription?.updatedFields)")
    case .delete:
        print("Deleted document: \(change.documentKey)")
    default:
        break
    }
}

// Type-safe change streams
struct User: Codable {
    let id: ObjectId
    let name: String
    let email: String
}

let typedStream = try await users.watch(type: User.self)
for try await change in typedStream {
    if let user = change.fullDocument {
        print("User modified: \(user.name)")
    }
}
```

## Logging and Monitoring

MongoKitten provides built-in support for logging and monitoring:

```swift
// Add logging metadata
let loggedDb = db.adoptingLogMetadata([
    "service": "user-api",
    "environment": "production"
])

// Use the logged database
let users = loggedDb["users"]
```

## Best Practices

### Connection Management

- Use `lazyConnect` for development and non-critical services
- Use `connect` for production services where immediate feedback is important
- Always specify `authSource` in your connection string
- Use connection pooling for better performance

### Performance Optimizations

- Use appropriate indexes for your queries
- Limit result sets when possible
- Use projection to fetch only needed fields
- Consider using change streams instead of polling
- Use batch operations for bulk updates/inserts

# Troubleshooting

<details>
  <summary>I can't connect to MongoDB, authentication fails!</summary>
  
  1. Make sure you've specified `authSource=admin`, unless you know what your authSource is. MongoDB's default value is really confusing.
  2. If you've specified an `authMechanism`, try removing it. MongoKitten can detect the correct one automatically.
</details>

<details>
  <summary>Change streams not working</summary>
  
  1. Ensure you're connected to a replica set or sharded cluster
  2. Check that your user has the required privileges
  3. Verify that you're not trying to watch system collections
</details>

<details>
  <summary>Performance issues</summary>
  
  1. Check your indexes using `explain()`
  2. Monitor connection pool usage
  3. Ensure you're not fetching unnecessary fields
  4. Use appropriate batch sizes for bulk operations
</details>

# Meow ORM

Meow works as a lightweight but powerful ORM layer around MongoKitten.

## Setting up Meow
Add the product `"Meow"` as a dependency for your target.
```swift
.product(name: "Meow", package: "MongoKitten"),
```
Import `"Meow"` before using it.
```swift
import Meow
```
## Setting up with Vapor
```swift
extension Application {
    public var meow: MeowDatabase {
        MeowDatabase(mongo)
    }
}

extension Request {
    public var meow: MeowDatabase {
        MeowDatabase(mongo)
    }
}
```

## Models

There are two main types of models in Meow, these docs will focus on the most common one.

When creating a model, your type must implement the `Model` protocol.

```swift
import Meow

struct User: Model {
  ..
}
```

Each Model has an `_id` field, as required by MongoDB. The type must be Codable and Hashable, the rest is up to you. You can therefore also make `_id` a compound key such as a `struct`. It must still be unique and hashable, but the resulting Document is acceptable for MongoDB.

Each field must be marked with the `@Field` property wrapper:

```swift
import Meow

struct User: Model {
  @Field var _id: ObjectId
  @Field var email: String
}
```

You can also mark use nested types, as you'd expect of MongoDB. Each field in these nested types must also be marked with the `@Field` property wrapper to make it queryable.

```swift
import Meow

struct UserProfile: Model {
  @Field var firstName: String?
  @Field var lastName: String?
  @Field var age: Int
}

struct User: Model {
  @Field var _id: ObjectId
  @Field var email: String
  @Field var profile: UserProfile
}
```

### Queries

Using the above model, we can query it from a MeowCollection. Get your instance from the MeowDatabase using a typed subscript!

```swift
let users = meow[User.self]
```

Next, run a `find` or `count` query, but using a type-checked syntax instead! Each portion of the path needs to be prefixed with `$` to access the `Field` property wrapper.

```swift
let adultCount = try await users.count(matching: { user in
  user.$profile.$age >= 18
})
```

As meow just recycles common MongoKitten types, you can use a find query cursor as you'd do in MongoKitten.

```swift
let kids = try await users.find(matching: { user in
  user.$profile.$age < 18
})

for try await kid in kids {
  // TODO: Send verification email to parents
}
```

### References

Meow has a helper type called `Reference`, you can use this in your model instead of copying the identifier over. This will give you some extra helpers when trying to resolve a models.

Reference is also `Codable` and inherit's the identifier's `LosslessStringConvertible`. So it can be used in Vapor's JWT Tokens as a subject, or in a Vapor's Route Parameters.

```swift
// GET /users/:id using Vapor
app.get("users", ":id") { req async throws -> User in
  let id: Reference<User> = req.parameters.require("id")
  return try await id.resolve(in: req.meow)
}
```

## Backers

<a href="https://github.com/ultim8p"><img src="https://avatars3.githubusercontent.com/u/4804985?s=460&v=4" width="128" height="128" /></a>