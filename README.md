# MongoKitten

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver. It uses:

- IBM's [BlueSocket](https://github.com/IBM-Swift/BlueSocket) for TCP connections
- Our own [BSON](https://github.com/PlanTeam/BSON) library, which is also 100% native Swift

## Setup

Add to your Package.swift:

```swift
import PackageDescription

let package = Package(
	name: "MyApp",
	dependencies: [
		.Package(url: "https://github.com/PlanTeam/MongoKitten.git", majorVersion: 0)
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

try collection.insertAll(docs)
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

## License

MongoKitten is licensed under the MIT license.