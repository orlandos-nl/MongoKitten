# MongoKitten

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver. It uses:

- IBM's [BlueSocket](https://github.com/IBM-Swift/BlueSocket) for TCP connections
- Our own [BSON](https://github.com/PlanTeam/BSON) library, which is also 100% native Swift

## Requirements

- A mongoDB server
- Swift Development Snapshot 2016-03-01-a

We don't support any other version of swift with the constantly changing syntax. This required swift version changes constantly with newer versions of `MongoKitten` and it's recommended to pin down the version in SPM.

Note: other versions of `swift` and `MongoDB` may or may not work. We do not support them.

## Setup

Add to your Package.swift:

```swift
import PackageDescription

let package = Package(
	name: "MyApp",
	dependencies: [
		.Package(url: "https://github.com/PlanTeam/MongoKitten.git", majorVersion: 0, minor: 3)
	]
)
```

## Usage

### Connecting to a server and doing a simple query

```swift
import MongoKitten
import BSON

do {
	let server = try Server(host: "127.0.0.1")
	try server.connect()
	
	let collection = server["nicedatabase"]["nicecollection"]
	
	for user in try collection.find("username" == "harriebob") {
		// do something with the user
	}
} catch {
	// do something with the error
}
```

### Connecting to a server with authentication

```swift
import MongoKitten
import BSON

do {
	let server = try Server(host: "127.0.0.1", authentication = (username: "my-user", password: "my-pass"))
	try server.connect()
	
	let collection = server["nicedatabase"]["nicecollection"]
	
	for user in try collection.find("username" == "harriebob") {
		// do something with the user
	}
} catch {
	// do something with the error
}
```

### More complex queries
```swift
var q: Query = "username" == "henk" && "age" > 24

if userDefinedThing {
	q &= "male" == true
}

// You can initialize an array with a Cursor to fetch all data at once:
let results = try Array(collection.find(q))
```

```swift
for u in try collection.find("username" == "Robbert" || "username" == "Joannis") {
	// ....
	// break from the loop when finished and the driver won't fetch additional data:
	if gotWhatsNeeded {
		break
	}
}
```

You can do a custom query by not using the query operators:

```swift
let r = try collection.find(["username": "henk"])
```

### Inserting a document

```swift
try collection.insert(["username": "henk", "password": "fred"])
```

### Inserting multiple documents

```swift
let docs: [Document] = [
	["username": "Bob", "password": "Fred"],
	["username": "Harrie", "password": "Bob"]
]

try collection.insert(docs)
```

### Listing collections

```swift
let collections = try database.getCollections() // returns a Cursor<Collection>
for collection in collections {
	// ...
}
```

### Full CRUD

```swift
// Create:
try collection.insert(["username": "henk", "age": 245])

// Read:
try collection.find("username" == "henk") // Cursor<Document>
try collection.findOne("username" == "henk") // Document?

// Update:
try collection.update("username" == "henk", ["$set": ["username": "fred"]], flags: [.Upsert])

// Delete:
try collection.remove("age" > 24)
```

### GridFS

```swift
// Make a GridFS Collection within the database 'mydatabase'
let gridFS = GridFS(database: server["mydatabase"])

// Find all bytes corresponding to this image
let data = NSData(contentsOfFile: "./myimage.jpg")!

// Store the file in GridFS with maximum 10000 bytes per chunk (255000 is the recommended default) and doesn't need to be set
// Store the ObjectID corresponding to the file in a constant variable
let objectID = try! gridFS.storeFile(data, chunkSize: 10000)

// Retreive the file from GridFS
let file = try! gridFS.findOneFile(objectID)

// Make a buffer to store this file's data in
var buffer = [UInt8]()

// Loop over all chunks of data in the file
for chunk in try! file!.findChunks() {
    // Append the chunk to the buffer
    buffer.appendContentsOf(chunk.data.data)
}

return buffer
```

### GridFS example usage

Imagine running a video streaming site. One of your users uploads a video. This will be stored in GridFS within 255000-byte chunks.

Now one user starts watching the video. You'll load the video chunk-by-chunk without keeping all of the video's buffer in memory.

The user quits the video about 40% through the video. Let's say chunk 58 of 144 of your video. Now you'll want to start continueing the video where it left off without receving all the unneccesary chunks.

We'd do that like this:

```swift
for var chunk in try file.findChunks(skip: 57) {
	...
}
```

## Notes

Because we're using `CryptoSwift` in our authentication we're having issues with *release builds*. Currently.. if you want to compile `MongoKitten`'s dependency you'll need to run `swift build` without `--configuration release`. This primarily affects users of `Heroku` where the most popular buildpack is making use of the `--configuration release` parameters.

Due to a limitation in Swift, when embedding a document or array in a BSON document literal, you need to use the `*` prefix operator:

```swift
try collection.insert(["henk": *["fred", "harriebob"]])
```

## Security notes

In our library we support both the use of `query` as well as `find`.

`query` works on every MongoDB version. And `find` works on MongoDB 3.2 and higher.

The difference might be complex but is important.

`Query` is a powerful Message since it's used to run database commands as described [here](https://docs.mongodb.org/manual/reference/command/).

If you use `Query` on a database in the collection `$cmd` you're able to perform CRUD operations on users, collections and other data. This can be abused in a similar way to SQL Injection.

Therefore it's a good idea to check all Documents that enter the `query` command to prevent malicious behaviour.

## License

MongoKitten is licensed under the MIT license.
