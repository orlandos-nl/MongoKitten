# Cursor

Cursor is a type within a client (like MongoKitten) that points to a set of results from a query.
This query can be a [find](find.md) or [aggregate](aggregates.md) operation.

FindOne technically also uses a cursor, but will automatically select the first (and only) result if it exists.

### (Un-)finalized

In MongoKitten we represent cursor as two public types, alongside an internal one.
All cursor types except `Finalized` are in an "unfinalized" state.

These cursors are essentially a wrapper around an operation, such as find or aggregate, that will be implicitly executed when read.
The only other type, the finalized cursor, can not be executed anymore since they're in a state of reading.

All cursors except finalized cursors will become a finalized cursor when executed.
You can not initialize your own finalized cursor, it has to be done through an uninitialized cursor provided by MongoKitten.

## Common use cases

There are a few patterns that are common when using cursors. Most of the time your action can be solved with (a combination of) the following operations.

### decode

`decode` is a feature that is only usable on a cursor of `Document`'s, these are the initial cursors that are returned when working with a `find` or `aggregate` operation.
Decode requires a `Decodable` type as an argument, such as `User.self`. The optional second argument is a preconfigured [BSONDecoder](bson-codable-settings.md) that can be used to modify the behaviour of the decoding process.

**Usages**

```swift
// Arbitrary query
users.find("age" > 40 && "age" < 50).decode(User.self).forEach { user in
    print(user.username)
}
```

### map

Mapping a cursor is similar to the `map` function on an `EventLoopFuture` (in Vapor `Future`).
You can think of cursor as an Asynchronous `Sequence`. It can be read once, from front to back and every value is created asynchronously.

`map` works like any array/sequence's map, transforming the type's contained values from one type to another using the provided function/closure.
This process is more efficient than using `getAllResults`, because the transformations are done in smaller chunks. This allows the memory usage to stay far lower than would be possible when mapping the array returned from `getAllResults` and is far more scalable.

**Usages**

Mapping a User object to return just the username from a `User` object:

```swift
// Arbitrary query
users.find("age" > 40 && "age" < 50).decode(User.self).map { user in
    return user.name
}.forEach { username in
    print(username)
}
```

Mapping a document to return just the username without decoding it first.

```swift
// Arbitrary query
enum MyCustomErrors: Error {
    case missingField(String)
}

users.find("age" > 40 && "age" < 50).project(["username"]).map { document in
    guard let username = document["username"] as? String else {
        throw MyCustomErrors.missingField("username")
    }

    return username
}.forEach { username in
    print(username)
}
```

### forEach

`forEach` takes each value in the cursor from the current position forward and calls the provided closure with each result
This works brilliantly when chained behind a cursor mapped with the `decode` and/or `map` functions.
Throwing from the callback closure will stop the entire iteration process.

`forEach` is a really strong replacement for iterating over `getAllResults` because it's far more efficient on memory which improves it's scalability.
Because it throws an error when iterating, this prevents the cursor for doing any additional unnecessary effort for the query when it's cancelled.
This is another big performance gain over `getAllResults`.

`forEach` also returns an `EventLoopFuture<Void>` which is completed when `forEach`. If the operation was cancelled due to an error being thrown, the future will not be completed successfully but failed with the thrown error instead.

**Usages**

Iterating over all users

```swift
users.find().forEach { document in
    print(document)
}
```

```swift
let completed = users.find().decode(User.self).forEach { user in
    user.sendNotification()
}

return completed.map {
    return "All users received the notification!"
}
```

### getFirstResult

The `getFirstResult` function will fetch exactly one more entity from the cursor. Normally this is useful when a query is executed that is known to have only 1 result, however it can be used to slowly but surely drain the cursor one document at a time.

**Usages**

```swift
users.find().getFirstResult().decode(User.self).onSuccess { user in
    if let user = user {
        print(user.username)
    }
}
```

### getAllResults

`getAllResults` is the simplest method of draining a cursor. The entire cursor will be put into one (big) array containing all entities. It's the most efficient and easy to use method when you want to fetch all entities at the same time, especially if it's unconditionally.

**Usages**

```swift
let usersJSON = users.find().getAllResults().map { users in
    return try JSONEncoder().encode(users)
}
```
