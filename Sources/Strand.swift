// Box.swift
// borrowed from https://github.com/vapor/core/blob/987fe68bafb4995865d10442122a14ade86c1805/Sources/Core/Box.swift
/*
 Vapor/core license:
 The MIT License (MIT)
 
 Copyright (c) 2016 Qutheory
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */
/**
 Box encapsulates values in a reference type for scenarios where it is required
 */
internal final class Box<T> {
    
    /**
     The underlying value
     */
    let value: T
    
    /**
     Create a reference counted box around a value
     - parameter value: the value to box
     */
    init(_ value: T) {
        self.value = value
    }
}


// Strand.swift
// borrowed from https://github.com/vapor/core/blob/987fe68bafb4995865d10442122a14ade86c1805/Sources/Core/Strand.swift
/*
 Copyright (c) 2016 @ketzusaka
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

public enum StrandError: Error {
    case creationFailed(Int)
    case cancellationFailed(Int)
    case joinFailed(Int)
    case detachFailed(Int)
}

internal final class Strand {
    public typealias Closure = () -> Void
    
    private var pthread: pthread_t
    
    public init(_ closure: Closure) throws {
        let box = Box(closure)
        let holder = Unmanaged.passRetained(box)
        let closurePointer = UnsafeMutableRawPointer(holder.toOpaque())
        
        #if os(Linux)
            var thread: pthread_t = 0
        #else
            var thread: pthread_t?
        #endif
        
        let result = pthread_create(&thread, nil, runner, closurePointer)
        // back to optional so works either way (linux vs macos).
        let inner: pthread_t? = thread
        
        guard result == 0, let value = inner else {
            holder.release()
            throw StrandError.creationFailed(Int(result))
        }
        pthread = value
    }
    
    deinit {
        pthread_detach(pthread)
    }
    
    public func join() throws {
        let status = pthread_join(pthread, nil)
        guard status == 0 else { throw StrandError.joinFailed(Int(status)) }
    }
    
    public func cancel() throws {
        let status = pthread_cancel(pthread)
        guard status == 0 else { throw StrandError.cancellationFailed(Int(status)) }
    }
    
    public func detach() throws {
        let status = pthread_detach(pthread)
        guard status == 0 else { throw StrandError.detachFailed(Int(status)) }
    }
    
    public class func exit(code: Int) {
        var code = code
        pthread_exit(&code)
    }
}

#if os(Linux)
    private func runner(_ arg: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
        return arg.flatMap { runner($0) }
    }
#endif

private func runner(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let unmanaged = Unmanaged<Box<() -> Void>>.fromOpaque(arg)
    unmanaged.takeUnretainedValue().value()
    unmanaged.release()
    return nil
}
