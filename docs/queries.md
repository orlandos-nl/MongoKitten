# Queries

MongoKitten supports both the [MongoDB query syntax](https://docs.mongodb.com/manual/reference/operator/query/) which bases on [`Document`](document.md) or using the MongoKitten query builder.

## MongoDB syntax

In the MongoDB docs the queries are written in JSON syntax:

```json
{ "qty": { "$gt": 20 } }
```

In MongoKitten you can use a dictionary literal but need to explicitly specify the top-level document as a Query. These literals work exactly like a Document.

```swift
let query: Query = [
    "qty": ["$gt": 20]
]
```

We won't be covering the MongoDB syntax in this document as they're already described in the official docs and actively maintained by MongoDB itself.

## MongoKitten syntax

MongoKitten queries are represented by the `Query` object. When specifying a query inline inside a function signature, the `Query` type does not need to be explicitly added since the compiler infers it from the function.

### Basic queries

MongoKitten queries are built using a swift-like syntax where a String is used for the key.

Have a look at the following query. It filters out all documents that have the `username` key with a String value of `"joannis"`.

```swift
let query: Query = "username" == "joannis"
```

As you can see, you can use normal comparison operators including `==`, `!=`, `>`, `<`, `>=` and `<=`. You can also wrap a query in a not using the `!` operator. You can bind multiple statements together using `&&` and `||` just like you would in an if-statement.

A few examples are below:

```swift
let teenagerQuery = "age" >= 10 && "age" < 20
let notTeenagerQuery: Query = !teenagerQuery
```

You can also combine a MongoKitten with a standard MongoDB query.

```swift
let base: Document = [
    "age": ["gte": 10]
]
let notTeenagerQuery: Query = !(base && "age" < 20)
```
