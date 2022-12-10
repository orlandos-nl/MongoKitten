<p align="center">

![](assets/ReadmeHeader.svg)

![](assets/Descriptions.gif)

</p>

A fast, pure swift [MongoDB](https://mongodb.com) driver based on [Swift NIO](https://github.com/apple/swift-nio) built for Server Side Swift. It features a great API and a battle-tested core. Supporting both MongoDB in server and embedded environments.

⭐️ Please leave a star to support MongoKitten – it really helps!

# 🐈 Community & Docs

[Join our Discord](https://discord.gg/H6799jh) for any questions and friendly banter.

### Projects

A couple of MongoKitten based projects have arisen, check them out!

- [MongoQueue](https://github.com/orlandos-nl/MongoQueue)
- [Vapor's Fluent + MongoDB](https://github.com/vapor/fluent-mongo-driver)
- [MongoDB + Vapor Queues](https://github.com/vapor-community/queues-mongo-driver)

# 🕶 Installation

## Set up MongoDB server

If you haven't already, you should set up a MongoDB server to get started with MongoKitten

For development, this can be on your local machine.

Install MongoDB for [Ubuntu](https://www.mongodb.com/docs/v6.0/tutorial/install-mongodb-on-ubuntu/), [macOS](hhttps://www.mongodb.com/docs/v6.0/tutorial/install-mongodb-on-os-x/) or any other supported Linux Distro.

Alternatively, make use of a DAAS (Database-as-a-service) like [MongoDB Atlas](https://cloud.mongodb.com).

## Add MongoKitten to your Swift project 🚀

MongoKitten uses the [Swift Package Manager](https://swift.org/getting-started/#using-the-package-manager). Add MongoKitten to your dependencies in your **Package.swift** file:

`.package(url: "https://github.com/orlandos-nl/MongoKitten.git", from: "7.2.0")`

Also, don't forget to add the product `"MongoKitten"` as a dependency for your target.

```swift
.product(name: "MongoKitten", package: "MongoKitten"),
```

### Add Meow (Optional)

Meow is an ORM that resides in this same package.

```swift
.product(name: "Meow", package: "MongoKitten"),
```

# FAQ

<details>
  <summary>I can't connect to MongoDB, authentication fails!</summary>
  
  1. Make sure you've specified `authSource=admin`, unless you know what your authSource is. MongoDB's default value is really confusing.
  2. If you've specified an `authMechanism`, try removing it. MongoKitten can detect the correct one automatically.
</details>

# 🚲 Basic usage

First, connect to a database:

```swift
import MongoKitten

let db = try await MongoDatabase.connect(to: "mongodb://localhost/my_database")
```

Vapor users should register the database as a service.

```swift
extension Request {
    public var mongoDB: MongoDatabase {
        return application.mongoDB
    }
    
    // For Meow users only
    public var meow: MeowDatabase {
        return MeowDatabase(mongoDB)
    }
    
    // For Meow users only
    public func meow<M: ReadableModel>(_ type: M.Type) -> MeowCollection<M> {
        return meow[type]
    }
}

private struct MongoDBStorageKey: StorageKey {
    typealias Value = MongoDatabase
}

extension Application {
    public var mongoDB: MongoDatabase {
        get {
            storage[MongoDBStorageKey.self]!
        }
        set {
            storage[MongoDBStorageKey.self] = newValue
        }
    }
    
    // For Meow users only
    public var meow: MeowDatabase {
        MeowDatabase(mongoDB)
    }
    
    public func initializeMongoDB(connectionString: String) throws {
        self.mongoDB = try MongoDatabase.lazyConnect(to: connectionString)
    }
}
```

And make sure to call `app.initializeMongoDB`!

## CRUD (Create, Read, Update, Delete)

Before doing operations, you need access to a collection where you store your models. This is MongoDB's equivalent to a table.

```swift
// The collection "users" in your database
let users = db["users"]
```

### Create (insert)

```swift
let myUser: Document = ["username": "kitty", "password": "meow"]

try await users.insert(myUser)
```

### Read (find) and the query builder

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
users.findOne(["username": "kitty"])
```

#### Cursors

Find operations return a `Cursor`. A cursor is a pointer to the result set of a query. You can obtain the results from a cursor by iterating over the results, or by fetching one or all of the results.

Cursors will close automatically if the enclosing `Task` is cancelled.

##### Fetching results

You can fetch all results as an array:

```swift
let users = try await users.find().drain()
```

Note that this is potentially dangerous with very large result sets. Only use `drain()` when you are sure that the entire result set of your query fits comfortably in memory.

##### Cursors are generic

Find operations return a `FindQueryBuilder`. You can lazily transform this (and other) cursors into a different result type by using `map`, which works similar to `map` on arrays or documents. A simple commonly used helper based on map is `.decode(..)` which decodes each result Document into a `Decodable` entity of your choosing.

```swift
let users: [User] = try await users.find().decode(User.self).drain()
```

### Update & Delete

You can do updateOne/many and deleteOne/many the same way you'd see in the MongoDB docs.

```swift
try await users.updateMany(where: "username" == "kitty", setting: ["age": 3])
```

The result is implicitly discarded, but you can still get and use it.

```swift
let reply = try await users.deleteOne(where: "username" == "kitty")
print("Deleted \(reply.deletes) kitties 😿")
```

# 📦 About BSON & Documents

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
- BSON primitives include core Swift types like `Int`, `String`, `Double` and `Bool`, as well as `Date` from Foundation
- BSON also features some unique types, like `ObjectId`

## Just another collection

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

# 💾 Codable

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

# Meow

Meow works as a lightweight but powerful ORM layer around MongoKitten.

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

You can also mark use nested types, as you'd expect of MongoDB. Each field in these nested types must also be makred with `@Field` to make it queryable.

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

Using the above model, we can query it from a MeowCollection. Get your instance from the MeowDatabase using a subscritp!

```swift
let users = meow[User.self]
```

Next, run a `find` or `count` query:

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
  // Send verificatin email to parents
}
```

### References

Meow has a helper type called `Reference`, you can use this in your model instead of copying the identifier over. This will give you some extra helpers when trying to resolve a models.

Reference is also `Codable` and inherit's the identifier's `LosslessStringConvertible`. So it can be used in Vapor's JWT Tokens as a subject, or in a Vapor's Route Parameters.

```swift
app.get("users", ":id") { req async throws -> User in
  let id: Reference<User> = req.parameters.require("id")
  return try await id.resolve(in: req.meow)
}
```

# ☠️ License

MongoKitten is licensed under the MIT license.

#### Backers

<a href="https://github.com/ultim8p"><img src="https://avatars3.githubusercontent.com/u/4804985?s=460&v=4" width="128" height="128" /></a>
