internal struct OK: Decodable {
    private let ok: Int

    internal var isSuccessful: Bool {
        return ok == 1
    }
}
