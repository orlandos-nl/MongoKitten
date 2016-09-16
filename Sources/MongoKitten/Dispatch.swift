// borrowed from https://github.com/vapor/core/blob/987fe68bafb4995865d10442122a14ade86c1805/Sources/Core/Dispatch.swift

import Foundation
import Dispatch

let backgroundQueue = DispatchQueue.global()

internal func background(_ function: @escaping () -> Void) throws {
    backgroundQueue.async(execute: function)
}


