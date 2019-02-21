# Doucment

Document is the top-level type in [MongoDB BSON](bson.md) and can be recursive, just like JSON.

### Creating a document

You can create a Document using a literal or the initializer.

```swift
var document = Document()
var dictionaryDocument: Document = [:]
var arrayDocument: Document = []
```

The keys in the literal _must_ be a String, values _must_ be a primitive including Document itself.

### Dictionary Subscripts

Setting a value to a Dictionary document works the same as a Dictionary.

```swift
var userDocument: Document = [
    "username": "Joannis"
]

// prints  Optional("Joannis")
print(userDocument["username"] as? String)

userDocument["username"] = "Robbert"

// prints  Optional("Robbert")
print(userDocument["username"] as? String)
```

Note that we have to cast the returned type with `as?` to a `String` when reading.
Because a Document can contain any [BSON primitive](bson.md) you will have to unwrap it's value as another value. The returned type will always be `Primitive`.

### Array subscripts

Setting and getting an array-object can be done using the same subscripts.

```swift
var names: Document = ["Joannis", "Robbert"]

// prints  Optional("Joannis")
print(names[0] as? String)

// prints  Optional("Robbert")
print(names[1] as? String)
```

Just like arrays, requesting an index that does not exist will crash:

```swift
// These all crash
print(names[-1] as? String)
print(names[2] as? String)
print(names[3] as? String)
```

### Common dictionary and array helpers

Like a dictionary, you can get all keys and values from a Document. The values are especially useful if you want the literal Array-representation of this Document. These work for any Document.

```swift
let dictionaryDocument: Document = [
    "username": "Joannis",
    "age": 22,
    "male": true
]

// [ "username", "age", "male" ]
print(dictionaryDocument.keys)

// [ "Joannis", 22, true ]
print(dictionaryDocument.values)
```

```swift
let arrayDocument: Document = [ "Joannis", 22, true ]

// [ "0", "1", "2" ]
print(dictionaryDocument.keys)

// [ "Joannis", 22, true ]
print(dictionaryDocument.values)
```

In addition to these you can use the common array and dictionary `append` functions.

```swift
let dictionaryDocument: Document = [
    "username": "Joannis",
    "age": 22,
    "male": true
]

dictionaryDocument.append("admin", forKey: "role")
```

```swift
let arrayDocument: Document = [ "Joannis", 22, true ]

arrayDocument.append("admin")
```

### Collection

When iterating over a Document, you'll be iterating over the key-value pairs.

```swift
let user: Document = [
    "username": "Joannis",
    "age": 22,
    "male": true
]

for (key, value) in user {
    print(key) // "username", then "age", then "male"
    print(value) // "Joannis", then `22`, then `true`
}
```

Iterating over the keys and values is also possible.

## Array- and Dictionary-like documents

JSON is represented like this in Swift:

```swift
// Object
[String: Primitive]

// Array
[Primitive]
```

Whereas BSON Documents are more accurately represented like this:

```swift
[ (String, Primitive) ]
```

Unlike Dictionaries and JSON Objects, BSON Documents keep a strict order. A dictionary or JSON Object would never guarantee any sequential order of pairs. The order of key-value pairs is arbitrary, unlike an array.

BSON Documents do, however, have keys unlike an array. The top-level BSON document is _always_ a Dictionary-like Document which is equivalent to an ordered key-value store. You can access the keys like you would in a Dictionary, except the order of insertion is kept by default.

Documents can contain other documents, too. These "sub-documents", as we'll call them, can be either an array- or dictionary-like document. Array-like documents normally represent their keys by an integer which relates to their index. However, it's not guaranteed that the value for the key `"3"` is on index `3`. The order of values is what matters in an array-document.
