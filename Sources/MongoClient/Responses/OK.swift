internal struct OK: Decodable {
    private enum CodingKeys: String, CodingKey {
        case ok
    }
    
    private let ok: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try container.decode(Int.self, forKey: .ok)
    }
}
