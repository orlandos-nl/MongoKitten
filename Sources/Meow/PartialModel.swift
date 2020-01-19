public struct PartialModel<M: Model> {
    public private(set) var document: Document
    
    public init(document: Document = Document()) {
        self.document = document
    }
}
