Please leave a star to show your support for the project.

# MongoKitten

[![Swift 3.1.0](https://img.shields.io/badge/swift-3.1.0-green.svg)](https://swift.org)
![License](https://img.shields.io/github/license/openkitten/mongokitten.svg)
[![Build Status](https://travis-ci.org/OpenKitten/MongoKitten.svg?branch=mongokitten4)](https://travis-ci.org/OpenKitten/MongoKitten)

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver.

## Requirements

- A MongoDB server (local or online) running MongoDB 2.6 or above. (MongoDB 3.2 or 3.4 is recommmended)
- Swift 3.1

Linux requries the OpenSSL library to be installed.

## Setting up MongoDB

Install MongoDB for [Ubuntu](https://docs.mongodb.com/master/tutorial/install-mongodb-on-ubuntu/), [macOS](https://docs.mongodb.com/master/tutorial/install-mongodb-on-os-x/) or [any other supported Linux Distro](https://docs.mongodb.com/master/administration/install-on-linux/).

Alternatively; make use of a DAAS (Database-as-a-service) like [MLab](https://mlab.com), [Bluemix](https://www.ibm.com/cloud-computing/bluemix/mongodb-hosting) or any other of the many services.

## Importing

Add this to your dependencies:

`.Package(url: "https://github.com/OpenKitten/MongoKitten.git", majorVersion: 4)`

And `import MongoKitten` in your project.

## Building

`swift build -c release`

## Supported Features

- All basic operations
- [Blazing fast performance](Performance.md)
- SSL, MongoDB-CR and SASL authentication
- Sharded Clusters and Replica Sets
- Geospatial queries
- Read/Write concerns + Collations
- User management and other Administrative commands
- Indexes
- GridFS and DBRef standards support
- Expressive Aggregation pipelines
- A simple yet effective QueryBuilder
- MongoDB Document queries
- Much more

## TODO

- X.509 certificate based authentication

## Learn

[Many articles on medium are listed here](https://www.reddit.com/r/swift/comments/65bvre/a_rapidly_growing_list_of_mongokittenswift_guides/) [and here](http://beta.openkitten.org).

[We host the MongoKitten documentation including dash docset here](http://mongokitten.openkitten.org/).

## Questions and ideas

[Join our slack here](https://slackpass.io/openkitten) or create an issue here on Github.

## Support

[We're accepting donations for our project here](https://opencollective.com/mongokitten)

The donations are used for creating and hosting tutorials, documentation and example projects.

## License

MongoKitten is licensed under the MIT license.
