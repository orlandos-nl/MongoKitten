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

var future: EventLoopFuture<InsertReply>?
var future2: EventLoopFuture<Int>?

try connection.map { connection -> Void in
    let collection = connection["test"]["test"]
    
    let user = MyUser(named: "kaas")
    
    let insert = InsertCommand([user], into: collection)
    future = insert.execute(on: connection)
    
    let single = DeleteCommand.Single(matching: "name" == "kaas")
    let delete = DeleteCommand([single], from: collection)
    future2 = delete.execute(on: connection)
}.wait()

print(try future?.wait())
print(try future2?.wait())
