Please leave a star to show your support for the project.

[![Swift 3.1.0](https://img.shields.io/badge/swift-3.1.0-green.svg)](https://swift.org)
![License](https://img.shields.io/github/license/openkitten/mongokitten.svg)
[![Build Status](https://travis-ci.org/OpenKitten/MongoKitten.svg?branch=mongokitten4)](https://travis-ci.org/OpenKitten/MongoKitten)

# MongoKitten

![OpenKitten](http://openkitten.org/background-openkitten.svg)

MongoKitten is a native, production-ready MongoDB driver written in pure Swift. It is the **fastest MongoDB driver available** on any platform, while providing a **great Swift API** that is a joy to use.

## Core features	

- Production ready
- No complex setup procedure, just import and go
- Extremely performant 🚀
- Pure Swift
- Great API
- Fast with support for new MongoDB and Swift features and versions

## Requirements

- A MongoDB server (local or online) running MongoDB 2.6 or above. (MongoDB 3.2 or 3.4 is recommmended)
- Swift 3.1 or greater

Linux requries the `libssl-dev` library to be installed.

## Setting up MongoDB

Install MongoDB for [Ubuntu](https://docs.mongodb.com/master/tutorial/install-mongodb-on-ubuntu/), [macOS](https://docs.mongodb.com/master/tutorial/install-mongodb-on-os-x/) or [any other supported Linux Distro](https://docs.mongodb.com/master/administration/install-on-linux/).

Alternatively; make use of a DAAS (Database-as-a-service) like [Atlas](https://cloud.mongodb.com), [MLab](https://mlab.com), [Bluemix](https://www.ibm.com/cloud-computing/bluemix/mongodb-hosting) or any other of the many services.

## Getting started

Add MongoKitten to your `Package.swift`:

`.Package(url: "https://github.com/OpenKitten/MongoKitten.git", majorVersion: 4)`

After a `swift package update`, you can now use MongoKitten:

```swift
import MongoKitten

let myDatabase = try MongoKitten.Database("mongodb://localhost/my_database")
let myCollection = myDatabase["my_collection"]

for document in try myCollection.find("foo" > 42) {
    // do something with document
}
```

For more information on how to use MongoKitten, [visit the documentation](http://mongokitten.openkitten.org/).

## Building for performance

Always compile MongoKitten in **release** mode for production and benchmarks. MongoKitten has proven to be 100-200x faster on release mode compared to debug compilation. Both Xcode and SPM use debug compilation by default.

`swift build -c release`

## Learn

Many articles on medium are listed [here](https://www.reddit.com/r/swift/comments/65bvre/a_rapidly_growing_list_of_mongokittenswift_guides/) and [here](http://beta.openkitten.org).

[We host the MongoKitten **documentation** including dash docset here](http://mongokitten.openkitten.org/).

## Community

[Join our slack here](https://slackpass.io/openkitten) and become a part of the welcoming community.

[Learn more about contributing here](CONTRIBUTING.md).

Contributors are always welcome. Questions can be discussed on slack or in github issues. We also take part in the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## Support

[We're accepting donations for our project here](https://opencollective.com/mongokitten). We hope to set up a good test environment as well as many docs, tutorials and examples.

## Performance

MongoKitten is faster than other MongoDB drivers.

Driver | Execution time
-------|----------------
MongoKitten 4 | 525ms
Java (post JIT optimizations) | 585ms
C                        | 605ms
Ruby                     | 1200ms
Java (pre JIT optimizations) | 1205ms

## License

MongoKitten is licensed under the MIT license.
