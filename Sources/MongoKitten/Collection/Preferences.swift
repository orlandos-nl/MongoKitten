public struct Preferences {
    public var readConcern: ReadConcern?
    public var writeConcern: WriteConcern?
    public var collation: Collation?
    
    /// The default cursor strategy to use server-wide
    public var cursorStrategy: CursorStrategy = .intelligent(bufferChunks: 3)
    
    public init() {}
}
