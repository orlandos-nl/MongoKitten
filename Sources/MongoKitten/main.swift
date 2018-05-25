import NIO
import Foundation

let group = MultiThreadedEventLoopGroup(numThreads: 1)

let connection = try MongoDBConnection.connect(on: group)

struct MyUser: Codable {
    var _id = ObjectId()
    var name: String
    init(named name: String) {
        self.name = name
    }
}

var future: EventLoopFuture<InsertCommand<MyUser>.Result>?
try connection.thenThrowing { connection -> Void in
    let user = MyUser(named: "kaas")
    
    let collectionRef = CollectionReference(to: "test", inDatabase: "test")
    let insert = InsertCommand([user], into: collectionRef)
    future = try insert.execute(on: connection)
}.wait()

print(try future?.wait())
