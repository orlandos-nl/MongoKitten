# MongoKitten

[![Swift 3.0.1](https://img.shields.io/badge/swift-3.0.1-orange.svg)](https://swift.org)
![License](https://img.shields.io/github/license/openkitten/mongokitten.svg)
[![Build Status](http://cimongo.l18.io:8080/buildStatus/icon?job=MongoKitten(3.1.X))](http://cimongo.l18.io:8080/job/MongoKitten(3.1.X))

Native MongoDB driver for Swift, written in Swift. This library does not wrap around the mongoc driver. It uses:

- Our own [BSON](https://github.com/OpenKitten/BSON) library, which is also 100% native Swift
- Our own [MD5, SHA1, SCRAM and PBKDF2 libraries](https://github.com/OpenKitten/CryptoKitten) in 100% Swift (currently included in the package)
- Optional support for SSL/TLS using LibreSSL

## Importing

Add this to your `Package.swift` for the stable

`.Package(url: "https://github.com/OpenKitten/MongoKitten.git", majorVersion: 3)`

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

We host all our documentation [here](http://docs.openkitten.org).

## Tests

To run tests on your local machine you must have a running `mongod` instance on your localhost and accessible via 27017 port.
Tests use the `zips` collection in `mongokitten-unittest` database. Retrieve the dataset from [here](https://raw.githubusercontent.com/OpenKitten/Mongo-Assets/master/zips.json) and save to a file named `zips.json`.
In the system shell or command prompt, use `mongoimport` to insert the `zips` collection in the `mongokitten-unittest` database. If the collection already exists the operation will drop the `zips` collection first.

```sh
mongoimport --db=mongokitten-unittest --collection=zips --drop zips.json
```

## Supporters

To keep this project up and running we have [a donation page set up here.](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=265MBC3CZFN7Y) If you add your email address we'll contact you and we'll put your photo underneath here.

## License

MongoKitten is licensed under the MIT license.
