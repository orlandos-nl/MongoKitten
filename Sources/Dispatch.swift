// borrowed from https://github.com/vapor/core/blob/987fe68bafb4995865d10442122a14ade86c1805/Sources/Core/Dispatch.swift

#if os(Linux)
    internal func background(_ function: @escaping () -> Void) throws {
        let _ = try Strand(function)
    }
#else
    import Foundation
    
    let backgroundQueue = DispatchQueue.global()
    
    internal func background(_ function: @escaping () -> Void) throws {
        backgroundQueue.async(execute: function)
    }
#endif

