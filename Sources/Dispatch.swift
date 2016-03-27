#if os(Linux)
    import NSLinux
#else
    import Foundation
#endif

internal func backgroundThread() -> dispatch_queue_t {
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
}

internal func Background(thread: dispatch_queue_t = backgroundThread(),
                       _ function: () -> Void) {
    dispatch_async(thread, function)
}
