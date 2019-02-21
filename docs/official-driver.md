# Differences with the official Swift MongoDB driver

Since Server Side Swift started quickly taking off recently, companies have had more interest in Swift. MongoDB has been building a driver based on their C driver [on github](https://github.com/mongodb/mongo-swift-driver#or-install-the-driver-using-cocoapods).

This page lists the pro's and cons of both drivers in relation to the other.

### (A)synchronous

The most important difference between both drivers is that MongoKitten 5 is asynchronous using Swift-NIO whereas the official driver is synchronous and does not support Swift-NIO. This is not an easy fix for MongoDB as it would require them to rewrite the entire driver from scratch.

For applications using a database driver in a blocking situation this means that sending a query is a simpler task. In opposite scenario's, this means MongoKitten is the only good choice as introducing a blocking client, which the current state of the official driver is, will bring a huge hit to the performance of your application.

For applications in a Swift-NIO environment, which most users such as Vapor users are, this not only means impacting the performance but also giving up the integrations with Swift-NIO which MongoKitten leverages for simplicity and more performance.

This also means that (asynchronous) applications will need to create many instances of the official client for the parallelisation of queries whereas MongoKitten does not.

### Support

The official driver is written and maintained by MongoDB. This means that MongoDB will have support available for big companies and that they have some guarantees about the project being maintained.

MongoKitten is a community-driver project. This means that anyone can fork the project and apply bug fixes on their own. We, the creators, are not responsible for maintaining it at all.

### API

MongoKitten is built completely on Swift, meaning no additional (language) limitations are present. MongoDB's driver, being built on C, is impacted by the limitations of both.

This allows MongoKitten to have simpler APIs. Alongside that we more heavily rely on labels when multiple arguments are needed to improve readability.

Interestingly enough, MongoDB decided to use a few of the same techniques that were used in MongoKitten 4 for their API. This is not feasible for us any longer as it would imply blocking the thread. This is not something we can do in an asynchronous environment and we would welcome the community to create (a public library with) some helpers for this themselves if there is a demand.

This difference makes MongoDB's API subjectively better in synchronous environments than MongoKitten. However, aside from the lack of asynchronous/Swift-NIO support in the official driver, the MongoKitten driver is subjectively (according to community) nicer once these helpers are out of the equation.

### Performance

Aside from the performance impact induced by the driver being blocking/synchronous the driver has a relatively big amount of overhead due to the C-interoperability in Swift. When communicating with C, Swift will make many copies which are sometimes unnecessary to ensure stability. This has a large impact on the MongoDB driver, although the C-interoperability difference is small compared to the saved performance of going asynchronous.
