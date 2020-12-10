<p align="center">

![OpenKitten](assets/ReadmeHeader.svg)

![OpenKitten](assets/Descriptions.gif)

[Installation](#-installation) | [Tutorial](https://www.raywenderlich.com/10521463-server-side-swift-with-mongodb-getting-started) | [Basic usage](#-basic-usage) | [About BSON](#-about-bson--documents) | [Codable](#-codable) | [Community](#-community) | [How to help](#-how-to-help)

</p>

A fast, pure swift [MongoDB](https://mongodb.com) driver based on [Swift NIO](https://github.com/apple/swift-nio) built for Server Side Swift. It features a great API and a battle-tested core. Supporting both MongoDB in server and embedded environments.

⭐️ Please leave a star to support MongoKitten – it really helps!

# 🐈 Community

[Join our slack here](https://slackpass.io/openkitten) and become a part of the welcoming community. Or [join discord](https://discord.gg/H6799jh) if you prefer that. Slack is by far the biggest community.

### Projects

A couple of MongoKitten based projects have arisen, check them out!

- [Fluent MongoDB](https://github.com/vapor/fluent-mongo-driver)
- [MongoDB Queues](https://github.com/vapor-community/queues-mongo-driver)

# 🤝 How to help

## Support MongoKitten development

[You can sponsor us via GitHub.](https://github.com/sponsors/Joannis). This enables us to provide a higher quality and more documentation as well as building more tools.

#### Backers

<a href="https://github.com/Andrewangeta"><img src="https://avatars2.githubusercontent.com/u/12012815?s=460&u=ed30851422c52b43608cf1b3d654c1c921006910&v=4" width="128" height="128" /></a> <a href="https://github.com/piers12"><img src="https://avatars1.githubusercontent.com/u/37227905?s=460&u=2f33baff0e70c4194c801e1bc9a2b416e8cf5909&v=4" width="128" height="128" /></a> <a href="https://github.com/ultim8p"><img src="https://avatars3.githubusercontent.com/u/4804985?s=460&v=4" width="128" height="128" /></a>

## The App

[MongoKitten App](https://apps.apple.com/us/app/mongokitten/id1484086700) can help you browse your dataset, support customers and debug complex aggregates.

## The Person

I'm a freelancer, actively improving the MongoKitten ecosystem. [Hire me!](mailto:joannis@orlandos.nl)

## Contribute to MongoKitten

- [Donate](https://github.com/sponsors/Joannis) so that we can spend more time on improving the docs.
- See [CONTRIBUTING.md](CONTRIBUTING.md) for info on contributing to MongoKitten
- You can help us out by resolving TODOs and replying on issues
- Of course, all feedback, positive and negative, also really helps to improve the project

# 🕶 Installation

## Set up MongoDB server

If you haven't already, you should set up a MongoDB server to get started with MongoKitten

For development, this can be on your local machine.

Install MongoDB for [Ubuntu](https://docs.mongodb.com/master/tutorial/install-mongodb-on-ubuntu/), [macOS](https://docs.mongodb.com/master/tutorial/install-mongodb-on-os-x/) or [any other supported Linux Distro](https://docs.mongodb.com/master/administration/install-on-linux/).

Alternatively, make use of a DAAS (Database-as-a-service) like [MongoDB Atlas](https://cloud.mongodb.com), [MLab](https://mlab.com), [IBM Cloud](https://cloud.ibm.com/catalog/services/databases-for-mongodb) or any other of the many services.

## Add MongoKitten to your Swift project 🚀

If you're using a SwiftNIO 1.x framework such as Vapor 3, use [MongoKitten 5](https://github.com/OpenKitten/MongoKitten/tree/master/5.0) instead.

MongoKitten supports the [Swift Package Manager](https://swift.org/getting-started/#using-the-package-manager) for server-side applications. Add MongoKitten to your dependencies in your **Package.swift** file:

`.package(url: "https://github.com/OpenKitten/MongoKitten.git", from: "6.0.0")`

Also, don't forget to add `"MongoKitten"` as a dependency for your target.

# FAQ

<details>
  <summary>I can't connect to MongoDB, authentication fails!</summary>
  
  1. Make sure you've specified `authSource=admin`, unless you know what your authSource is. MongoDB's default value is really confusing.
  2. If you've specified an `authMechanism`, try removing it. MongoKitten can detect the correct one automatically.
</details>

# 🚲 Basic usage

Check out my [Ray Wenderlich Article](https://www.raywenderlich.com/10521463-server-side-swift-with-mongodb-getting-started) to learn the basics!

## Connect to your database

```swift
import MongoKitten

let db = try MongoDatabase.synchronousConnect("mongodb://localhost/my_database")
```

Vapor users should register the database as a service.

```swift
extension Request {
    public var mongoDB: MongoDatabase {
        return application.mongoDB.hopped(to: eventLoop)
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
        self.mongoDB = try MongoDatabase.lazyConnect(connectionString, on: self.eventLoopGroup)
    }
}
```

And make sure to call `app.initializeMongoDB`!

## NIO Futures

MongoKitten relies on [Swift NIO](https://github.com/apple/swift-nio) to provide support for asynchronous operations. All MongoKitten operations that talk to the server are asynchronous, and return an EventLoopFuture of some kind.

You can learn all about NIO by reading [its readme](https://github.com/apple/swift-nio/blob/master/README.md) or [the article on RayWenderlich.com](https://www.raywenderlich.com/1124580-a-simple-guide-to-async-on-the-server), but here are the basics:

Asynchronous operations return a future. NIO implements futures in the [`EventLoopFuture<T>`](https://apple.github.io/swift-nio/docs/current/NIO/Classes/EventLoopFuture.html) type. An `EventLoopFuture` is a holder for a result that will be provided later. The result of the future can either be successful yielding a result of `T`, or unsuccessful with a result of a Swift `Error`. This is the asynchronous representation of a successful `return` or a thrown error.

If you're using [Vapor 4](https://vapor.codes), please refer to their [Async documentation](https://docs.vapor.codes/4.0/async/overview/). Vapor's Async module provides additional helpers on top of NIO, that make working with instances of `EventLoopFuture<T>` easier.

If you use Vapor or another Swift-NIO based web framework, *never* use the `wait()` function on `EventLoopFuture` instances.

## CRUD (Create, Read, Update, Delete)

```swift
// The collection "users" in your database
let users = db["users"]
```

### Create (insert)

```swift
let myUser: Document = ["username": "kitty", "password": "meow"]

let future: Future<InsertReply> = users.insert(myUser)

future.whenSuccess { _ in
	print("Inserted!")
}

future.whenFailure { error in
	print("Insertion failed", error)
}
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
users.findOne("username" == "kitty").whenSuccess { user: Document? in
	// Do something with kitty
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
users.find("age" <= 16 || "age" == nil).forEach { user: Document in
	// Print the user's name
	print(user["username"] as? String)
}
```

You can also type out the queries yourself, without using the query builder, like this:

```swift
users.findOne(["username": "kitty"])
```

#### Cursors

Find operations return a `Cursor`. A cursor is a pointer to the result set of a query. You can obtain the results from a cursor by iterating over the results, or by fetching one or all of the results.

##### Fetching results

You can fetch all results as an array:

`let results: EventLoopFuture<[Document]> = users.find().getAllResults()`

Note that this is potentially dangerous with very large result sets. Only use `getAllResults()` when you are sure that the entire result set of your query fits comfortably in memory.

##### Iterating over results

For more efficient handling of results, you can lazily iterate over a cursor:

```swift
let doneIterating: EventLoopFuture<Void> = users.find().forEach { user: Document in
	// ...
}
```

##### Cursors are generic

Find operations return a `FindCursor<Document>`. As you can see, `FindCursor` is a generic type. You can lazily transform the cursor into a different result type by using `map`, which works similar to `map` on arrays or documents:

```swift
users.find()
	.map { document in
		return document["username"] as? String
	}
	.forEach { username: String? in
		print("user: \(username)")
	}
```

### Update

```swift
users.updateMany(where: "username" == "kitty", setting: ["age": 3]).whenSuccess { _ in
	print("🐈")
}
```

### Delete

```swift
users.deleteOne(where: "username" == "kitty").whenSuccess { amountDeleted in
	print("Deleted \(amountDeleted) kitties 😿")
}
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

## Codable and cursors

When doing a `find` query, the `Cursor`'s results can be transformed lazily. Lazy mapping is much more efficient than keeping the entire result set in memory as it allows for `forEach-` loops to be leveraged efficiently reducing the memory pressure of your application. You can leverage cursors using Codable as well.

```swift
// Find all and decode each Document lazily as a `User` type
users.find().decode(User.self).forEach { user in
	print(user.username)
}
```

# ☠️ License

MongoKitten is licensed under the MIT license.
