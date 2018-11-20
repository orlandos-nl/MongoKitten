Please leave a star to show your support for the project.

[![Swift 4.1.0](https://img.shields.io/badge/swift-4.1.0-green.svg)](https://swift.org)
![License](https://img.shields.io/github/license/openkitten/mongokitten.svg)

# MongoKitten

![OpenKitten](http://openkitten.org/background-openkitten.svg)

Native MongoDB driver for Swift, written in Swift.

## Requirements

- A MongoDB server (local or online) running MongoDB 3.2 or above. (MongoDB 4 is recommmended)
- Swift 4.1 or greater

## Getting Started

### Setting up MongoDB

If you haven't already, you should set up a MongoDB server to get started with MongoKitten. For development, this can be on your local machine.

Install MongoDB for [Ubuntu](https://docs.mongodb.com/master/tutorial/install-mongodb-on-ubuntu/), [macOS](https://docs.mongodb.com/master/tutorial/install-mongodb-on-os-x/) or [any other supported Linux Distro](https://docs.mongodb.com/master/administration/install-on-linux/).

Alternatively, make use of a DAAS (Database-as-a-service) like [MongoDB Atlas](https://cloud.mongodb.com), [MLab](https://mlab.com), [Bluemix](https://www.ibm.com/cloud-computing/bluemix/mongodb-hosting) or any other of the many services.

### Adding MongoKitten to your Swift project

MongoKitten currently only supports the [Swift Package Manager](https://swift.org/getting-started/#using-the-package-manager). Add MongoKitten to your Package.swift file:

`.package(url: "https://github.com/OpenKitten/MongoKitten.git", from: "5.0.0")`

Also, don't forget to add `"MongoKitten"` as a dependency for your target.

### Connect to your database

TODO: Code samples

## Learn

[We host the MongoKitten documentation including dash docset here](http://mongokitten.openkitten.org/).

## Community

[Join our slack here](https://slackpass.io/openkitten) and become a part of the welcoming community.

[Learn more about contributing here.](CONTRIBUTING.md)

Contributors are always welcome. Questions can be discussed on Slack or in GitHub issues. We also take part in the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## Support

[We're accepting donations for our project here](https://opencollective.com/mongokitten). We hope to set up a good test environment as well as many docs, tutorials and examples.

## Production environments & benchmarks

Always compile MongoKitten in **release** mode for production and benchmarks. MongoKitten has proven to be much faster on release mode compared to debug compilation. Debug compilation is what Xcode and the Swift Package Manager use by default.

`swift build -c release`

## Developing MongoKitten

See [CONTRIBUTING.md](CONTRIBUTING.md) for info on contributing to MongoKitten.

## License

MongoKitten is licensed under the MIT license.
