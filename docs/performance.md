# Performance in MongoKitten

MongoKitten's performance comes from the fundamental principles that power [Swift-NIO](https://github.com/apple/swift-nio).

MongoKitten exposes asynchronous (non-blocking) API's only, allowing a single thread to run thousands or queries in parallel, at the same time.
[BSON Documents](bson.md), the primitive types of MongoDB, are implemented in a fashion that is highly optimised for Swift-NIO with even better performance being reasonably possible.
Aside from that, BSON Documents are Copy on Write, meaning copying a Document around is thread-safe but won't be using additional memory/resources until you modify a copy.

Because we integrate with Swift-NIO, many deeper optimisations and better APIs are achievable within the Server Side Swift ecosystem as almost all actively maintained libraries have started or finished migrating to Swift-NIO since it's release.

We have not set up a recent benchmark suite yet, [contributions are welcome!](contribute.md#benchmarks)
