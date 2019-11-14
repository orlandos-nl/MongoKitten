public struct PartialModel<M: _Model> {
    public private(set) var document: Document
    
    public init(document: Document = Document()) {
        self.document = document
    }
}
