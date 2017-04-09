Please leave a star to show your support for the project.

# MongoKitten

[![Swift 3.0.1](https://img.shields.io/badge/swift-3.0.1-orange.svg)](https://swift.org)
![License](https://img.shields.io/github/license/openkitten/mongokitten.svg)
[![Build Status](https://travis-ci.org/OpenKitten/MongoKitten.svg?branch=mongokitten31)](https://travis-ci.org/OpenKitten/MongoKitten)

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver. It uses:

- Our own [BSON](https://github.com/OpenKitten/BSON) library, which is also 100% native Swift
- Our own [MD5, SHA1, SCRAM and PBKDF2 libraries](https://github.com/OpenKitten/CryptoKitten) in 100% Swift (currently included in the package)
- Optional support for SSL/TLS using LibreSSL

## Requirements

- A MongoDB server (local or online) running MongoDB 2.6 or above. (MongoDB 3.2 or 3.4 is recommmended)
- Swift 3.1

## Setting up MongoDB

Install MongoDB for [Ubuntu](https://docs.mongodb.com/master/tutorial/install-mongodb-on-ubuntu/), [macOS](https://docs.mongodb.com/master/tutorial/install-mongodb-on-os-x/) or [any other supported Linux Distro](https://docs.mongodb.com/master/administration/install-on-linux/).

Alternatively; make use of a DAAS (Database-as-a-service) like [MLab](https://mlab.com), [Bluemix](https://www.ibm.com/cloud-computing/bluemix/mongodb-hosting) or any other of the many services.

## Importing

Add this to your dependencies:

`.Package(url: "https://github.com/OpenKitten/MongoKitten.git", "4.0.0-vaportls")`

And `import MongoKitten` in your project.

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

[We host all our tutorials here](http://tutorials.openkitten.org)

[And we host the MongoKitten documentation including dash docset here](http://docs.openkitten.org/mongokitten/)

## Support

[We're accepting donations for our project here](https://opencollective.com/mongokitten)

The donations are used for creating and hosting tutorials, documentation and example projects.

## License

MongoKitten is licensed under the MIT license.
