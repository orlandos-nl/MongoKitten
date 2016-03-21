# MongoKitten

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver. It uses:

- IBM's [BlueSocket](https://github.com/IBM-Swift/BlueSocket) for TCP connections
- Our own [BSON](https://github.com/PlanTeam/BSON) library, which is also 100% native Swift

## Requirements

- MongoDB 3.x or higher
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

## Notes

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
