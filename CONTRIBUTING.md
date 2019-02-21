# Contributing

Contributors help keep a project growing and alive.

In a project like this, contributing code can be very intimidating, but that doesn't mean that you can't help.

## Contributing code

The best way to start contributing code is by reading the codebase. One way to approach that is by contributing (inline) documentation for the code at hand.

This way you're reading how the code at hand works and helps future contributors and users understand the code better, too.

### Build script

We use a few tools to aid in the development of MongoKitten, including SwiftLint and Sourcery. While not strictly neccesary to contribute to MongoKitten, they help keep some code up to date and ensure code quality on a few critical points.

Because it is not possible to include these tools as a build phase with the Swift Package Manager, the MongoKitten repository contains a script, `GenerateXcodeproj.rb`, that does the following things:

- It calls `swift package generate-xcodeproj`
- It opens the generated Xcode project and adds some files to it that SPM doesn't (like this readme and configuration files)
- It configures a build phase for SwiftLint and Sourcery

To use the build script, first install the `xcodeproj` Rubygem by running `sudo gem install xcodeproj`. You can then generate the Xcode project by running `./GenerateXcodeproj.rb` from the project root directory.

### Related projects

- [NIO](https://github.com/apple/swift-nio)
- [NIO-SSL](https://github.com/apple/swift-nio-ssl)
- [BSON](https://github.com/OpenKitten/BSON) 

## Contributing knowledge

What problems did you experience when you started out using the project?
Someone else will have the same issue, sooner or later. You can write your journey into finding the solution in an article or FAQ.

## Contributing ideas

What is a project without fresh ideas? Some of our ideas might be old or may not cover your user case.

## Contributing time

Many users seek help when using libraries. Just being there to help them out is just as important as contributing code.
