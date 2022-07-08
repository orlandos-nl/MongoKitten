#if os(Linux)
import Foundation

extension Date {
    func ISO8601Format() -> String {
        ISO8601DateFormatter().string(from: self)
    }
}
#endif
