# MongoKitten

[![Swift 3.0](https://img.shields.io/badge/swift-3.0-orange.svg)](https://swift.org)
![License](https://img.shields.io/github/license/openkitten/mongokitten.svg)
[![Build Status](https://api.travis-ci.org/OpenKitten/MongoKitten.svg?branch=mongokitten3)](https://travis-ci.org/OpenKitten/MongoKitten)

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver. It uses:

- Our own [BSON](https://github.com/OpenKitten/BSON) library, which is also 100% native Swift
- Our own [MD5, SHA1, SCRAM and PBKDF2 libraries](https://github.com/OpenKitten/CryptoKitten) in 100% Swift (currently included in the package)
- Optional support for SSL/TLS using LibreSSL

## Importing

Add this to your `Package.swift` for the stable

`.Package(url: "https://github.com/OpenKitten/MongoKitten.git", majorVersion: 2)`

Or add this to your `Package.swift` for the beta of MongoKitten 3

`.Package(url: "https://github.com/OpenKitten/MongoKitten.git", "3.0.0-beta")`

And `import MongoKitten` in your project.

## Supported Features

- SSL (MongoKitten 3)
- Sharded Clusters (MongoKitten 3)
- Replica Sets (MongoKitten 3)
- DBRefs (MongoKitten 3)
- GridFS
- Aggregates
- All basic MongoDB features

## Requirements

A MongoDB server (local or online) running MongoDB 2.6 or above.

## Learn

We host all our documentation [here](https://github.com/OpenKitten/Documentation/blob/master/README.md).

[Click here for MongoKitten tutorials](https://github.com/OpenKitten/Documentation/blob/master/MongoKitten/Tutorials/README.md)

[Click here for the migration guide](https://github.com/OpenKitten/Documentation/blob/master/MongoKitten/Migration/MK3.md)

## Backers

To keep this project up and running we have [a donation page set up here.](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=265MBC3CZFN7Y) If you add your email address we'll contact you and we'll put your photo underneath here.

## License

MongoKitten is licensed under the MIT license.
