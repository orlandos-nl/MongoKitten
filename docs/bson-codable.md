# BSON + Codable

BSON is a format that relates to `structs` and `classes` really easily. Putting data into MongoDB and retrieving it has to be done with Documents, but your Swift projects likely (and should) be embracing type-safety instead. Luckily, we have an Encoder and Decoder for that.

### Requirements

Leveraging `BSONEncoder` and `BSONDecoder` requires the type being converted to/from to be conformant to `Encodable` for encoding from type to Document, `Decodable` for Document to type or just `Codable` for both.

Conformance has to be done with the declaration of the type:

```swift
// This works
struct User: Codable {
    var username: String
}


// This does not
struct Company {
    var name: String
}

extension Company: Codable {}
```

## Using the BSONEncoder

`BSONEncoder` is the type that can convert from a swift type to a Document. You can configure it. [There's more information about that.](bson-codable-settings.md)

The encoding process works like this:

```swift
let encoder = BSONEncoder()
let document = try encoder.encode(user)
```

## Using the BSONDecoder

`BSONDecoder` is the type that can convert from a Document to a swift type. [There's more information about configuring it.](bson-codable-settings.md)

The decoding process works like this:

```swift
let decoder = BSONDecoder()
let user = try decoder.decoder(User.self, from: document)
```
