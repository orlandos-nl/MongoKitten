import NIO

public class Cursor<Element> {
    
    init() {
        unimplemented()
    }
    
    func map<T>(_ transform: (Element) throws -> T) -> Cursor<T> {
        unimplemented()
    }
    
    func forEach(_ body: (Element) throws -> Void) -> EventLoopFuture<Void> {
        unimplemented()
    }
    
}
