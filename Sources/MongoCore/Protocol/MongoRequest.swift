import BSON
import NIO

public protocol MongoMessage {
    var header: MongoMessageHeader { get set }
    
    init(reading buffer: inout ByteBuffer, header: MongoMessageHeader) throws
    func write(to out: inout ByteBuffer)
}
    
public protocol MongoRequestMessage: MongoMessage {}
public protocol MongoResponseMessage: MongoMessage {}
