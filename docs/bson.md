# BSON

BSON is the data format used across MongoDB and thus MongoKitten. It's a format that is highly compressible and is really lightweight to read and write for computers at the cost of human readability.

BSON is ideal for representing common types such as structs or classes thanks to it's wide range of supported types including Dictionary- and Array-like types. [This makes BSON an excellent companion when used with codable.](bson-codable.md)

## Document

Document is an ordered key-value store and is the only valid top-level entity in BSON. Think of it as a mix between JSON arrays and objects.
Documents come in two flavours, Array- and Dictionary-like BSON Documents.

### API

Because Document is such a big and important object, [the full documentation was moved elsewhere.](document.md)

## ObjectId

ObjectId is a 12-byte identifier that contains 3 pieces of data that aim to guarantee uniqueness. This is the most common and recommended [identifier](identifier.md) for entities.

ObjectId's first four bytes are a (big-endian) Int32 representing the UNIX epoch time in seconds when the ObjectId was generated. This can be useful for sorting entities in MongoDB. This implies that you do _not_ need to store a separate creation `Date` in your entity. You can rely on the creation-date residing within ObjectId.

### API

To create an ObjectId you can simply call the initializer.

```swift
let objectId = ObjectId()
```

If you're generating many id's, it's recommended to use an ObjectIdGenerator, which has a lot of optimizations that would not be achievable within ObjectId. ObjectIdGenerator is not thread safe as a result.

```swift
let generator = ObjectIdGenerator()
let objectId = generator.generate()
```

Reading the creation date can be done using the `epoch` or `epochSeconds` property. `epoch` returns a Foundation `Date` whereas `epochSeconds` returns an `Int32` containing the UNIX epoch creation date in seconds.

```swift
let id = ObjectId()
print(id.epoch) // now
```

When exposing ObjectId to another (non-BSON) encoder it will represent itself as a `String` using a hexadecimal representation instead.

To read this representation in code you can read the `hexString` property.

```swift
let id = ObjectId()
print(id.hexString)
```

## Standard types

The following types are directly supported using their Swift type and get no additional APIs.

- Int32
- Int (64-bits assumed)
- Double
- Bool
- String
- Date

## Null

Most BSON APIs allow for optional values, this makes writing an explicit `null` value close to impossible. For this reason, BSON provides the `Null` type.

```swift
let nothing = Null()
```

## Binary

Binary is a field that can be used to store any binary data, from hashes to files. It's also a critical value for GridFS.

You can create a binary from any [Swift-NIO](https://github.com/apple/Swift-NIO) `ByteBuffer`.
As a helper, you can get the Foundation `Data` by reading the `data` property on a Binary value.

## Decimal128

Decimal128 is a quadrupel-precision floating point type. This type is largely unsupported by us, for now. We hope to have better support in an update.

## MongoDB internal types

- Timestamp
- MinKey
- MaxKey

The above types are supported in a bare-minimum implementation because they're values specific to the MongoDB server internals.
