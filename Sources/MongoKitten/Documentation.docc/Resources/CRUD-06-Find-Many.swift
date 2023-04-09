struct Kitten: Codable {
    let _id: ObjectId
    let name: String
    let age: Date
}

let kitten = Kitten(
    _id: ObjectId(),
    name: "Milo",
    age: Date(timeIntervalSince1970: 1617540152)
)

try await kittens.insertEncoded(kitten)

func getKitten(byId id: ObjectId) async throws {
    guard let kitten = try await kittens.findOne("_id" == id, as: Kitten.self) else {
        struct KittenNotFound: Error {}
        throw KittenNotFound()
    }

    return kitten
}

let kittenCopy = try await getKitten(byId: kitten._id)

// Loop over all kittens
for try await kitten in kittens.find().decode(Kitten.self) {
    print(kitten)
}
