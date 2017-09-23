public struct Preferences {
    public var readConcern: ReadConcern?
    public var writeConcern: WriteConcern?
    public var collation: Collation?
    
    public init() {}
}
