# Getting Started with MongoKitten

This guide helps you to get started using MongoKitten. Think of it as a guided tour, explaining how to use the most important features.

## A note on NIO

MongoKitten relies on [NIO](https://github.com/apple/swift-nio) to provide a high performance, asynchronous API. NIO provides types like `EventLoopFuture` and allows MongoKitten to communicate to the MongoDB server.

Because explaining NIO is outside of the scope of this document, we will use the `wait()` function whenever we show an operation that returns a Future.

## Connecting to a database

The easiest way to connect to a MongoDB server is by using the `Database.synchronousConnect(...)` method with a connection string:

```swift
import MongoKitten

let db = try Database.synchronousConnect("mongodb://localhost/MyDatabase")
```

In NIO environments, like Vapor, you would use the `Database.connect` method, which requires you to pass a NIO eventLoop.

## Querying a collection

To execute a query on a collection, you first need a reference to the collection. You do this by subscripting your database object:

`let collection = db["myCollection"]`

Then, you can execute a query by calling the `find()` method:

`let cursor = collection.find()`

This results in a cursor that you can use to read the results. For example, you can loop over the results using `forEach`:

`collection.find().forEach { print($0) }`

**Note:** The `forEach` function returns an `EventLoopFuture`, and executes asynchronously, because the cursor may need to request additional results from the server. In non-NIO environments, you can `wait()` for the results: `try cursor.forEach {...}.wait()`

## Filtering with the query builder

The `find` operation shown above results in all documents from the collection. Mostly, you will want to filter the documents returned. MongoKitten provides a great query builder, based on Swift operators. You can pass the query as an argument to methods like `find`, `findOne` and `count`.

The query builder works mostly like the Swift operators you already know, so for most queries, you don't need to know the MongoDB query syntax. For example, a MongoKitten query can look like this:

`collection.find("age" > 20)`

The difference with conventional operators, is that as left hand side, you provide a `String` containing the key of the field you want to query.

The query shown above will be translated by MongoKitten to the following MongoDB query:

`{ "age": { "$gt": 20 } }`

You can also use other common operators. Some examples of valid queries:

```swift
"age" > 20 && "age" < 60
"age" == 40
("email" == "janjanssen@example.com" && "firstName" == "Jan") || ("email" == "harriejanssen@example.com" && "firstName" == "Harrie")
```

## Inserting data

Insert data by using the `insert` function:

`collection.insert(["name": "Henk", "age": 23]`

Our BSON library, which provides the `Document` type used by MongoDB, allows you to construct documents with dictionary syntax. Documents also behave like dictionaries and arrays in a lot of ways.

## Decodable types

MongoKitten is great with types that are `Decodable`. Consider this example:

```swift
struct User: Decodable {
    var username: String
    var email: String
}

collection.find().decode(User.self).forEach { user in
    // `user` is an instance of `User`
}
```

## Cursors

### Cursors are lazy

MongoKitten cursors are lazy. This means that no database command will be executed until results are needed. Thus, the following code does not execute a query on the database:

`collection.find()`

But the following code does:

`collection.find().forEach { print($0) }`

### Mapping a cursor

You can map cursors to a different type. Map operations are lazy.

`cursor.map { $0["foo"] }`

### Limit, skip, and sort

To limit, skip, or sort your results, use the methods on cursor:

`collection.find().skip(10).limit(50).sort(["date": .ascending]).forEach { ... }`

## Aggregates

MongoKitten provides a great aggregate builder, which you can use by calling `aggregate()` on `Collection`.

```swift
collection.aggregate()
    .match("status" == "A")
    .group(id: "$cust_id", ["total": .sum("$amount"))
```
