Please leave a star to show your support for the project.

# MongoKitten

[![Swift 3.0.1](https://img.shields.io/badge/swift-3.0.1-orange.svg)](https://swift.org)
![License](https://img.shields.io/github/license/openkitten/mongokitten.svg)
[![Build Status](https://travis-ci.org/OpenKitten/MongoKitten.svg?branch=mongokitten31)](https://travis-ci.org/OpenKitten/MongoKitten)

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver. It uses:

- Our own [BSON](https://github.com/OpenKitten/BSON) library, which is also 100% native Swift
- Our own [MD5, SHA1, SCRAM and PBKDF2 libraries](https://github.com/OpenKitten/CryptoKitten) in 100% Swift (currently included in the package)
- Optional support for SSL/TLS using LibreSSL

## Importing

Add this to your `Package.swift` for the stable

`.Package(url: "https://github.com/OpenKitten/MongoKitten.git", majorVersion: 3)`

Or add this to use with Kitura

`.Package(url: "https://github.com/lgaches/MongoKitten.git", "3.1.0-beta3")`

And `import MongoKitten` in your project.

## Supported Features

- All basic CRUD operations
- [Blazing fast performance](Performance.md)
- SSL
- Sharded Clusters
- Replica Sets
- Geospatial queries (3.1)
- Read/Write concerns (3.1)
- Collation (3.1)
- User management
- Indexes
- DBRef
- GridFS
- Aggregation pipelines
- Much more

## Requirements

- A MongoDB server (local or online) running MongoDB 2.6 or above.
- Swift 3.x.x

## Learn

[We host all our tutorials here](http://docs.openkitten.org)

[And we host the MongoKitten documentation including dash docset here](http://mongokitten.openkitten.org)

## License

MongoKitten is licensed under the MIT license.
