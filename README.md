# MongoKitten

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver. It uses:

- IBM's [BlueSocket](https://github.com/IBM-Swift/BlueSocket) for TCP connections
- Our own [BSON](https://github.com/PlanTeam/BSON) library, which is also 100% native Swift

## Requirements

- A mongoDB server
- Swift Development Snapshot 2016-03-24-a

We don't support any other version of swift with the constantly changing syntax. This required swift version changes constantly with newer versions of `MongoKitten` and it's recommended to pin down the version in SPM.

Note: other versions of `swift` and `MongoDB` may or may not work. We do not support them.

# Tutorial

## Setup

Add `MongoKitten` to your Package.swift:

```swift
import PackageDescription

let package = Package(
	name: "MyApp",
	dependencies: [
		.Package(url: "https://github.com/PlanTeam/MongoKitten.git", majorVersion: 0, minor: 4)
	]
)
```

Import the MongoKitten library:

```swift
import MongoKitten
```

Connect to your local MongoDB server:

```swift
do {
	let server = try Server(host: "127.0.0.1")

} catch {
	print("MongoDB is not available on the given host and port")
}
```

Or an external server with an account:

```swift
let server = try Server(host: "example.com", port: 27017, authentication: (username: "my-user", password: "my-pass"))
```

Select a database to use for your application:

```swift
let database = server["mydatabase"]
```

And select your collections to use from the database:

```swift
let userCollection = database["users"]
let otherCollection = database["otherdata"]
```

## Creating Documents

In `MongoKitten` we use our own `BSON` library for working with MongoDB Documents.

You can create a simple user document like this:

```swift
let userDocument: Document = [
	"username": "Joannis",
	"password": "myPassword",
	"age": 19,
	"male": true
]
```

If you want to embed documents or arrays you'll need the `*` prefix operator before your embedded document like this:

```swift
let testDocument: Document = [
	"example": "data",
	"embeddedDocument": *[
		"name": "Henk",
		"male": false,
		"age": 12,
		"pets": *["dog", "dog", "cat", "mouse"]
	]
]
```

## Inserting Documents

Using the above document you can insert the data in the collection.

```swift
try userCollection.insert(testDocument)
```

In the collection's insert method you can also insert a group of Documents: `[Document]`

```swift
try userCollection.insert([testDocument, testDocument, testDocument])
```

## Finding data

To find the Documents in the collection we'll want to use `find` or `findOne` on the collection.

```swift
// Lists all Documents in the Collection
let resultUsers = try userCollection.find()
```

This returns a cursor that you can use to loop over users. `MongoKitten`'s `Cursor` by default loads 10 Documents at a time from `MongoDB` which is customizable to a bigger or smaller amount of Documents.

This allows us to provide a smaller delay when looping over data. This also allows the application to remove the cursor halfway through the Documents without downloading Documents that aren't being used.

Looping over the above results is easy:

```swift
for userDocument in resultUsers {
	 print(userDocument)
	
    if userDocument["username"]?.stringValue == "harriebob" {
        print(userDocument)
    }
}
```

If you do want all Documents in one array. For example when exporting all data in a collection to CSV you can use `Array()`:

```swift
let allUserDocuments = Array(resultUsers)
```

### QueryBuilder

We also have a query builder which can be easily used to create filters when searching for Documents.

```swift
let q: Query = "username" == "harriebob" && "age" > 24

let result = try userCollection.findOne(q)
```

Or simpler:

```swift
let newResult = try userCollection.findOne("username" == "harriebob" && "age" > 24)
```

## Updating data

Updating data is simple too:

```swift
try userCollection.update(["username": "bob"], updated: ["username": "anotherbob"])
```

## Deleting data

Deleting is possible using a document and a query

```swift
// Delete using a document
try userCollection.remove(["username": "klaas"])

// Delete using a query:
try userCollection.remove("age" >= 24)
```

## GridFS

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
var buffer = [Byte]()

// Loop over all chunks of data in the file
for chunk in try! file!.findChunks() {
    // Append the chunk to the buffer
    buffer.appendContentsOf(chunk.data.data)
}
```

### GridFS example usage

Imagine running a video streaming site. One of your users uploads a video. This will be stored in GridFS within 255000-byte chunks.

Now one user starts watching the video. You'll load the video chunk-by-chunk without keeping all of the video's buffer in memory.

The user quits the video about 40% through the video. Let's say chunk 58 of 144 of your video. Now you'll want to start continueing the video where it left off without receving all the unneccesary chunks.

We'd do that like this:

```swift
do {
    for chunk in try file.findChunks(skip: 57) {
	    // process the chunks
    }
} catch {
    print("Couldn't get the chunks")
}
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
