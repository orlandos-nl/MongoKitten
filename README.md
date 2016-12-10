# MongoKitten

[![Swift 3.0](https://img.shields.io/badge/swift-3.0-orange.svg)](https://swift.org)
![License](https://img.shields.io/github/license/openkitten/mongokitten.svg)

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver. It uses:

- Our own [BSON](https://github.com/OpenKitten/BSON) library, which is also 100% native Swift
- Our own [MD5, SHA1, SCRAM and PBKDF2 libraries](https://github.com/OpenKitten/CryptoKitten) in 100% Swift (currently included in the package)
- Optional support for SSL/TLS using LibreSSL

## Supported Features

- SSL
- Sharded Clusters
- Replica Sets
- GridFS
- DBRefs

## Requirements

A MongoDB server (local or online) running MongoDB 2.6 or above.

## Learn

We host all our documentation [here](https://github.com/OpenKitten/Documentation/blob/master/README.md).

[Click here for MongoKitten tutorials](https://github.com/OpenKitten/Documentation/blob/master/MongoKitten/Tutorials/README.md)

[Click here for the migration guide](https://github.com/OpenKitten/Documentation/blob/master/MongoKitten/Migration/MK3.md)

## License

MongoKitten is licensed under the MIT license.
