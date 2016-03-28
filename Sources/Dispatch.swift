import Strand

public typealias Block = () -> Void

/// Execute a closure in the background
internal func Background(function: Block) throws {
    let _ = try Strand(closure: function)
}