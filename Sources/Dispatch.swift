#if os(Linux)
    import NSLinux
#else
    import Foundation
#endif

public func Background(function: () -> Void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), function)
}
