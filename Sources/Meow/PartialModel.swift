public struct PartialModel<M: BaseModel> {
    public private(set) var document: Document
    
    public init(document: Document = Document()) {
        self.document = document
    }
}
