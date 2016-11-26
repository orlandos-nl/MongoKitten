import BSON

public protocol DocumentRepresentable: ValueConvertible {
    func makeDocument() -> Document
}

extension Document: DocumentRepresentable {
    public func makeDocument() -> Document {
        return self
    }
}
